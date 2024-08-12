//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./TreasuryRole.sol";

contract Staking is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    TreasuryRole
{
    // Constants
    uint256 public constant ONE_YEAR = 31536000; // One year in seconds.
    bytes32 public constant TREASURY = keccak256("TREASURY"); // Treasury role - use to withdraw tokne from contract.
    bytes32 public constant MANAGER = keccak256("MANAGER"); // Manager role - use for depositReward, pausePool, unpausePool.
    bytes32 public constant PROVIDER = keccak256("PROVIDER"); // Provider role - use for migrateStake.
    bytes32 public constant MULTISIG_TYPE_WITHDRAW = keccak256("WITHDRAW"); // Withdraw type, to create withdraw transaction.
    bytes32 public constant MULTISIG_TYPE_TREASURY = keccak256("TREASURY_ROLE"); // Treasury assigned type, to assign an account to treasury role.
    bytes32 public constant MULTISIG_TYPE_CHANGE_WALLET =
        keccak256("CHANGE_WALLET"); // Update withdraw wallet.

    struct Apy {
        uint256 rate;
        uint256 decimals;
    }

    struct StakeItem {
        uint256 poolIndex; // Index of staking pool.
        uint256 itemIndex; // Index of this item in pool.
        uint256 unlockTime; // The lock time, after this time users can claimed their rewards.
        Apy apy;
        uint256 stakedAmount; // Stake item amount.
        uint256 lastUpdatedTime; // Last updated time.
        uint256 remainingReward; // Remaining reward of stake item.
        address userAddress; // Address of user own this stake item.
        uint256 lockPeriod; // The lock duration of the item.
        uint256 bonusLockedTime; // Lock time bonus when upgrade stake item to different stake time.
        bool unstaked; // True if item is unstaked. Unstaked items cannot be claimed.
    }

    struct StakePool {
        uint256 poolIndex; // Index of staking pool.
        Apy apy; // Pool APY.
        uint256 lockPeriod; // The lock duration of the pool.
        uint256 totalStaked; // Total token staked in pool.
        uint256 totalRewardClaimed; // total reward claimed in pool.
        bool paused; // If true user cannot stake, restake, upgrade stake item.
        mapping(uint256 => StakeItem) stakeItem; // Mapping of stake items.
        uint256 totalStakeItem; // Total stake item in pool.
        mapping(address => uint256[]) userItemIndexes; // Mapping user address with array of stake item indexes.
        uint256 totalUserStaked; // Total user stake in pool.
    }

    struct Transaction {
        uint256 txIndex; // Index of transaction.
        uint256 amount; // Amount of withdraw token.
        address tokenAddress; // Token address.
        address submitter; // Address of submitter.
        bool executed; // Variable shows that transaction is executed or not.
        uint256 numConfirmations; // Number of confirmations to execute.
        bytes32 transactionType; // Transaction type, can be WITHDRAW or TREASURY_ROLE.
        address treasuryUserAddress; // Address of grant/revoke user.
        bool userGranted; // True if grant address to be TREASURY, false to revoke the role.
        address withdrawWallet; // New withdraw wallet address.
        uint256 expiredAt; // Request expired time.
    }

    struct UserPoolInfo {
        uint256 poolIndex;
        address userAddress;
        uint256 amount;
        uint256 closestUnlockTime;
    }

    ERC20Upgradeable public stakingToken; // Staking token instance.
    ERC20Upgradeable public rewardsToken; // Reward token instance.
    uint256 public numConfirmationsRequired; // number of confirmation needed to confirm a transaction.
    address public withdrawWallet; // Withdraw wallet.
    uint256 public minStakeAmount; // Minimun stake amount.
    address[] public stakedUsers; // Total staked user in every pool.
    StakePool[] public pools; // Array of staking pools.
    Transaction[] public multisigTransactions; // Array of withdraw transactions.
    mapping(uint256 => mapping(address => bool)) public isConfirmed; // Mapping from tx index => owner => bool
    uint256 public currentItemIndex;
    bool public stopAll;
    mapping(string => bool) public reqId; // Mapping reqId to check in migrate stake.

    event CreatePool(
        uint256 _poolIndex,
        uint256 _apyRate,
        uint256 _apyDecimals,
        uint256 _lockingPeriod
    );
    event UpdateStakingPool(
        uint256 _poolIndex,
        uint256 _lockPeriod,
        uint256 _apyRate,
        uint256 _apyDecimals
    );
    event UpdatePoolAPY(
        uint256[] _poolIndexArr,
        uint256[] _stakeItemIndexArr,
        uint256 _apyRate,
        uint256 _apyDecimals
    );
    event Stake(
        address _userCreateAddress,
        uint256 _stakeAmount,
        uint256 _poolIndex,
        address _stakeAddress
    );
    event MigrateStake(
        address _userCreateAddress,
        uint256 _stakeAmount,
        uint256 _poolIndex,
        address _stakeAddress,
        string _reqId
    );
    event Unstake(
        uint256 _poolIndex,
        uint256 _stakeItemIndex,
        address _userAddress,
        uint256 _amount,
        uint256 _totalRewardClaimed
    );
    event UnstakeAll(address _userAddress, uint256 _amount);
    event RestakeReward(
        uint256 _poolIndex,
        uint256 _stakeItemIndex,
        address _userAddress
    );
    event RestakeRewardAll(address _userAddress, uint256 _amount);
    event Restake(
        uint256 _poolIndex,
        uint256 _stakeItemIndex,
        address _userAddress,
        uint256 _newUnlockTime
    );
    event RestakeAll(uint256[] _poolIndexes, address _userAddress);
    event Claim(
        uint256 _poolIndex,
        uint256 _stakeItemIndex,
        address _userAddress,
        uint256 _amount,
        uint256 _totalRewardClaimed
    );
    event ClaimAll(address _userAddress, uint256 _amount);
    event UpgradeStakeItem(
        uint256 _poolIndex,
        uint256 _stakeItemIndex,
        uint256 _upgradedPoolIndex,
        uint256 _bonusLockedTime,
        uint256 _newUnlockTime,
        address _userAddress
    );
    event PausedPool(uint256 _poolIndex, uint256 _totalStaked, bool _paused);
    event UnpausedPool(uint256 _poolIndex, uint256 _totalStaked, bool _paused);
    event DepositRewardEvent(uint256 _amount, uint256 _totalReward);
    event WithdrawRewardPool(
        address _executer,
        uint256 _txIndex,
        uint256 _amount
    );
    event StopEmergency(address[] _userAddressArr, uint256 _amount);
    event SubmitTransaction(
        address indexed _submitter,
        uint256 indexed _txIndex,
        bytes32 _transactionType
    );
    event ConfirmTransaction(
        address indexed _userAddress,
        uint256 indexed _txIndex
    );
    event RevokeConfirmation(
        address indexed _revoker,
        uint256 indexed _txIndex
    );
    event ChangeWithdrawWallet(address _withdrawAddress, uint256 _txIndex);
    event ChangeStopAll(address _owner, bool _stopAll);

    modifier txExists(uint256 _txIndex) {
        require(
            _txIndex < multisigTransactions.length,
            "StakingPool: tx does not exist"
        );
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(
            !multisigTransactions[_txIndex].executed,
            "StakingPool: tx already executed"
        );
        _;
    }

    modifier userNotConfirmed(uint256 _txIndex) {
        require(
            !isConfirmed[_txIndex][msg.sender],
            "StakingPool: tx already confirmed"
        );
        _;
    }

    modifier confirmed(uint256 _txIndex) {
        require(
            isConfirmed[_txIndex][msg.sender],
            "StakingPool: tx not confirmed"
        );
        _;
    }

    modifier notExpired(uint256 _txIndex) {
        require(
            block.timestamp <= multisigTransactions[_txIndex].expiredAt,
            "StakingPool: this request is expired"
        );
        _;
    }

    modifier stopAllCheck(address _address) {
        if (stopAll) {
            require(
                _address == owner(),
                "Staking: This contract has stopped, only owner can access"
            );
        }
        _;
    }

    /**
     * @notice Initialize the contract, get called in the first time deploy
     * @param _stakingToken the staking token for the pools
     * @param _rewardToken the reward token for the pools
     */
    function initialize(
        address _stakingToken,
        address _rewardToken,
        address[] memory _treasuryAddresses,
        address[] memory _managerAddresses,
        address[] memory _providerAddresses,
        uint256 _numConfirmationsRequired,
        address _withdrawWallet
    ) public initializer {
        __Ownable_init(msg.sender);
        __AccessControl_init();
        __ReentrancyGuard_init();
        __TreasuryRoleInitializing(address(this));

        require(
            _stakingToken != address(0) && _rewardToken != address(0),
            "StakingPool: Staking token and reward token cannot be native token"
        );
        require(
            _withdrawWallet != address(0),
            "StakingPool: Withdraw wallet cannot be zero address"
        );
        require(
            _numConfirmationsRequired > 0,
            "StakingPool: Number of confirmation must be greater than 0"
        );

        stakingToken = ERC20Upgradeable(_stakingToken);
        rewardsToken = ERC20Upgradeable(_rewardToken);

        for (uint i = 0; i < _treasuryAddresses.length; i++) {
            grantTreasuryRole(TREASURY, _treasuryAddresses[i], msg.sender);
        }
        for (uint i = 0; i < _managerAddresses.length; i++) {
            _grantRole(MANAGER, _managerAddresses[i]);
        }
        for (uint i = 0; i < _providerAddresses.length; i++) {
            _grantRole(PROVIDER, _providerAddresses[i]);
        }
        withdrawWallet = _withdrawWallet;
        minStakeAmount = 500 * (10 ** 9);

        // Pool 10 days
        _createPool(1, 2, 5 minutes);

        // Pool 60 days
        _createPool(4, 2, 30 minutes);

        // Pool 180 days
        _createPool(9, 2, 1 hours);

        // Pool 365 days
        _createPool(5, 1, 6 hours);

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    /**
     * @notice Create new staking pool
     * @param _apyRate the rate of APY (e.g for 6% the rate is 6 and the decimals is 2)
     * @param _apyDecimals the power of 10 in APY (e.g for 6% the rate is 6 and the decimals is 2)
     * @param _lockingPeriod the locking time of staking pool
     */
    function createStakingPool(
        uint256 _apyRate,
        uint256 _apyDecimals,
        uint256 _lockingPeriod
    ) external nonReentrant stopAllCheck(msg.sender) onlyOwner {
        require(
            !(_apyRate == 0 && _apyDecimals == 0),
            "StakingPool: APY cannot be zero"
        );

        _createPool(_apyRate, _apyDecimals, _lockingPeriod);
    }

    /**
     * @notice Deposit rewards= tokens into the contract
     * @param _depositAmount the amount of token
     */
    function depositReward(
        address _tokenAddress,
        uint256 _depositAmount
    ) external nonReentrant onlyRole(MANAGER) {
        require(
            _depositAmount > 0,
            "StakingPool: Deposit amount cannot be zero"
        );
        require(
            _tokenAddress == address(stakingToken) ||
                _tokenAddress == address(rewardsToken),
            "StakingPool: cannot deposit token that not in the pool"
        );

        if (_tokenAddress == address(rewardsToken)) {
            rewardsToken.transferFrom(
                msg.sender,
                address(this),
                _depositAmount
            );
        } else {
            stakingToken.transferFrom(
                msg.sender,
                address(this),
                _depositAmount
            );
        }

        emit DepositRewardEvent(
            _depositAmount,
            rewardsToken.balanceOf(address(this))
        );
    }

    function changeStopAll(bool _stopAll) external nonReentrant onlyOwner {
        stopAll = _stopAll;
        emit ChangeStopAll(msg.sender, _stopAll);
    }

    /**
     * @notice Function to update min stake amount to each pool
     * @param _amount new min stake amount
     */
    function changeMinStakeAmount(
        uint256 _amount
    ) external nonReentrant onlyRole(MANAGER) {
        require(
            _amount > 0,
            "StakingPool: Cannot set min stake amount to zero"
        );

        minStakeAmount = _amount;
    }

    /**
     * @notice Function to pause the staking pool, users cannot perform actions after paused (stake, claim, restake, unstake)
     * @param _poolIndex the index of the staking pool
     */
    function pausePool(
        uint256 _poolIndex
    ) external nonReentrant onlyRole(MANAGER) {
        StakePool storage pool = pools[_poolIndex];
        require(
            _poolIndex >= 0 && _poolIndex < pools.length,
            "StakingPool: invalid pool index"
        );

        pool.paused = true;

        emit PausedPool(_poolIndex, pool.totalStaked, pool.paused);
    }

    /**
     * @notice Function to unpause all the action of the staking pool, users can perform action after unpaused (stake, claim, restake, unstake)
     * @param _poolIndex the index of the staking pool
     */
    function unpausePool(
        uint256 _poolIndex
    ) external nonReentrant onlyRole(MANAGER) {
        StakePool storage pool = pools[_poolIndex];
        require(
            _poolIndex >= 0 && _poolIndex < pools.length,
            "StakingPool: invalid pool index"
        );

        pool.paused = false;

        emit UnpausedPool(_poolIndex, pool.totalStaked, pool.paused);
    }

    /**
     * @notice Update staking pool values, only owner
     * @param _poolIndex the index of the staking pool
     * @param _poolLockPeriod the locking time of staking pool
     */
    function updateStakingPool(
        uint256 _poolIndex,
        uint256 _poolLockPeriod,
        uint256 _apyRate,
        uint256 _apyDecimals
    ) external nonReentrant onlyOwner {
        require(
            _poolIndex >= 0 && _poolIndex < pools.length,
            "StakingPool: invalid pool index"
        );

        StakePool storage stakePool = pools[_poolIndex];
        stakePool.lockPeriod = _poolLockPeriod;
        stakePool.apy.rate = _apyRate;
        stakePool.apy.decimals = _apyDecimals;

        emit UpdateStakingPool(
            _poolIndex,
            _poolLockPeriod,
            _apyRate,
            _apyDecimals
        );
    }

    /**
     * @notice Update stake items APY
     * @param _poolIndexArr array of pools
     * @param _stakeItemIndexArr array of stake items
     */
    function updateAPY(
        uint256[] memory _poolIndexArr,
        uint256[] memory _stakeItemIndexArr,
        uint256 _apyRate,
        uint256 _apyDecimals
    ) external nonReentrant onlyOwner {
        require(
            !(_apyRate == 0 && _apyDecimals == 0),
            "StakingPool: APY cannot be zero"
        );

        for (uint i = 0; i < _poolIndexArr.length; i++) {
            uint256 poolIndex = _poolIndexArr[i];
            StakePool storage pool = pools[poolIndex];

            // update pool stake item apy
            for (uint index = 0; index < _stakeItemIndexArr.length; index++) {
                uint256 itemIndex = _stakeItemIndexArr[index];
                StakeItem storage item = pool.stakeItem[itemIndex];
                _updateRewardRemaining(poolIndex, item);
                item.apy = Apy(_apyRate, _apyDecimals);
            }
        }

        emit UpdatePoolAPY(
            _poolIndexArr,
            _stakeItemIndexArr,
            _apyRate,
            _apyDecimals
        );
    }

    /**
     * @notice Stake function, add token to the pool to receive rewards
     * @param _poolIndex the index of the staking pool
     * @param _stakeAmount the amount of token to stake
     */
    function stake(
        uint256 _poolIndex,
        uint256 _stakeAmount
    ) external nonReentrant stopAllCheck(msg.sender) {
        require(
            _poolIndex >= 0 && _poolIndex < pools.length,
            "StakingPool: invalid pool index"
        );
        require(
            _stakeAmount >= minStakeAmount,
            "StakingPool: stake amount cannot be less than mininum stake amount"
        );
        _stake(_poolIndex, _stakeAmount, msg.sender);

        emit Stake(msg.sender, _stakeAmount, _poolIndex, msg.sender);
    }

    /**
     * @notice User can upgrade stake item, the item will be claimed before upgrade
     * @param _poolIndex the index of the staking pool
     * @param _stakeItemIndex the index of stake item
     * @param _upgradedPoolIndex the index of the upgraded staking pool
     */
    function upgradeStakeItem(
        uint256 _poolIndex,
        uint256 _stakeItemIndex,
        uint256 _upgradedPoolIndex
    ) external nonReentrant stopAllCheck(msg.sender) {
        StakePool storage pool = pools[_poolIndex];
        StakePool storage upgradedPool = pools[_upgradedPoolIndex];
        StakeItem storage stakeItem = pool.stakeItem[_stakeItemIndex];
        require(
            upgradedPool.lockPeriod > stakeItem.lockPeriod,
            "StakingPool: cannot upgrade to pools that have lower lock time"
        );
        require(
            stakeItem.userAddress == msg.sender,
            "StakingPool: This stake item belongs to another address"
        );
        require(!pool.paused, "StakingPool: Pool is paused");

        uint256 bonusTime;
        if (block.timestamp > stakeItem.unlockTime) {
            bonusTime = block.timestamp - stakeItem.unlockTime;
        }
        if (bonusTime > stakeItem.lockPeriod) {
            bonusTime = stakeItem.lockPeriod;
        }
        // claim item
        _claim(_poolIndex, stakeItem, pool);

        // update stake item info
        stakeItem.lockPeriod = upgradedPool.lockPeriod;
        stakeItem.bonusLockedTime = bonusTime;
        stakeItem.unlockTime =
            block.timestamp +
            upgradedPool.lockPeriod -
            stakeItem.bonusLockedTime;
        stakeItem.poolIndex = _upgradedPoolIndex;
        stakeItem.apy = upgradedPool.apy;

        // insert stake item to new pool
        upgradedPool.totalStaked =
            upgradedPool.totalStaked +
            stakeItem.stakedAmount;
        upgradedPool.totalStakeItem = upgradedPool.totalStakeItem + 1;
        if (upgradedPool.userItemIndexes[msg.sender].length == 0) {
            upgradedPool.totalUserStaked = upgradedPool.totalUserStaked + 1;
        }
        upgradedPool.userItemIndexes[msg.sender].push(stakeItem.itemIndex);
        upgradedPool.stakeItem[_stakeItemIndex] = stakeItem;

        // remove stake item from old pool
        pool.totalStaked = pool.totalStaked - stakeItem.stakedAmount;
        pool.totalStakeItem = pool.totalStakeItem - 1;
        if (pool.userItemIndexes[msg.sender].length == 1) {
            pool.totalUserStaked = pool.totalUserStaked - 1;
        }
        for (uint i = 0; i < pool.userItemIndexes[msg.sender].length; i++) {
            uint256 itemIndex = pool.userItemIndexes[msg.sender][i];
            if (itemIndex == stakeItem.itemIndex) {
                pool.userItemIndexes[msg.sender][i] = 0;
            }
        }
        delete pool.stakeItem[_stakeItemIndex];

        emit UpgradeStakeItem(
            _poolIndex,
            _stakeItemIndex,
            _upgradedPoolIndex,
            bonusTime,
            stakeItem.unlockTime,
            msg.sender
        );
    }

    /**
     * @notice Owner can create stake item for another user
     * @param _poolIndex the index of the staking pool
     * @param _stakeAmount the amount of token to stake
     * @param _stakeAddress the user address
     */
    function migrateStake(
        uint256 _poolIndex,
        uint256 _stakeAmount,
        address _stakeAddress,
        string memory _reqId
    ) external nonReentrant onlyRole(PROVIDER) {
        require(
            _poolIndex >= 0 && _poolIndex < pools.length,
            "StakingPool: invalid pool index"
        );
        require(_stakeAmount > 0, "StakingPool: stake amount cannot be 0");
        require(!reqId[_reqId], "StakingPool: this reqId is already exist");

        reqId[_reqId] = true;
        _stake(_poolIndex, _stakeAmount, _stakeAddress);

        emit MigrateStake(
            msg.sender,
            _stakeAmount,
            _poolIndex,
            _stakeAddress,
            _reqId
        );
    }

    /**
     * @notice Claim reward from one stake item, the stake amount will stays in the contract
     * @param _poolIndex the index of the staking pool
     * @param _stakeItemIndex the index of stake item that user want to harvest
     */
    function claim(
        uint256 _poolIndex,
        uint256 _stakeItemIndex
    ) external nonReentrant stopAllCheck(msg.sender) {
        StakePool storage pool = pools[_poolIndex];
        StakeItem storage stakeItem = pool.stakeItem[_stakeItemIndex];
        require(stakeItem.unstaked == false, "StakingPool: no reward to claim");

        _claim(_poolIndex, stakeItem, pool);
    }

    /**
     * @notice Claim reward from all stake item
     */
    function claimAll() external nonReentrant stopAllCheck(msg.sender) {
        uint256 totalClaimedAmount = 0;

        for (uint256 index = 0; index < pools.length; index++) {
            StakePool storage pool = pools[index];
            uint256[] memory userStakeIndexes = pool.userItemIndexes[
                msg.sender
            ];

            for (uint256 i = 0; i < userStakeIndexes.length; i++) {
                uint256 itemIndex = userStakeIndexes[i];
                StakeItem storage item = pool.stakeItem[itemIndex];

                if (item.userAddress != address(0)) {
                    // Check if the item is claimable before processing
                    totalClaimedAmount += item.remainingReward;
                    _claim(index, item, pool);
                }
            }
        }

        emit ClaimAll(msg.sender, totalClaimedAmount);
    }

    /**
     * @notice Unstake all staking tokens and also receive reward tokens from one stake item
     * @param _poolIndex the index of the staking pool
     * @param _stakeItemIndex the index of stake item that user want to unstake
     */
    function unstake(
        uint256 _poolIndex,
        uint256 _stakeItemIndex
    ) external nonReentrant stopAllCheck(msg.sender) {
        StakePool storage pool = pools[_poolIndex];
        StakeItem storage stakeItem = pool.stakeItem[_stakeItemIndex];
        require(
            stakeItem.unlockTime < block.timestamp,
            "StakingPool: this stake item cannot be unstaked yet"
        );

        _unstake(_poolIndex, stakeItem);
        emit Unstake(
            _poolIndex,
            _stakeItemIndex,
            msg.sender,
            stakeItem.stakedAmount,
            pool.totalRewardClaimed
        );
    }

    /**
     * @notice Unstake all staking tokens and also receive reward tokens from all user stake items
     */
    function unstakeAll() external nonReentrant stopAllCheck(msg.sender) {
        uint256 totalUnstakedAmount;
        for (uint256 index = 0; index < pools.length; index++) {
            StakePool storage pool = pools[index];
            uint256[] memory userStakeIndexes = pool.userItemIndexes[
                msg.sender
            ];

            for (uint256 i = 0; i < userStakeIndexes.length; i++) {
                uint256 itemIndex = userStakeIndexes[i];
                StakeItem storage item = pool.stakeItem[itemIndex];
                require(
                    item.unlockTime < block.timestamp,
                    "StakingPool: this stake item cannot be unstaked yet"
                );
                if (item.userAddress != address(0)) {
                    _unstake(index, item);
                    totalUnstakedAmount =
                        totalUnstakedAmount +
                        item.stakedAmount;
                }
            }
        }

        emit UnstakeAll(msg.sender, totalUnstakedAmount);
    }

    /**
     * @notice Transfer reward to stake amount without reset lock period of that stake item
     * @param _poolIndex the index of the staking pool
     * @param _stakeItemIndex the index of stake item that user want to restake
     */
    function restakeReward(
        uint256 _poolIndex,
        uint256 _stakeItemIndex
    ) external nonReentrant stopAllCheck(msg.sender) {
        _restakeReward(_poolIndex, _stakeItemIndex);
        emit RestakeReward(_poolIndex, _stakeItemIndex, msg.sender);
    }

    /**
     * @notice Transfer reward to stake amount all stake item without reset lock period
     * @param _amount new stake amount
     */
    function restakeRewardAll(
        uint256 _amount
    ) external nonReentrant stopAllCheck(msg.sender) {
        for (uint256 index = 0; index < pools.length; index++) {
            StakePool storage pool = pools[index];
            uint256[] memory userStakeIndexes = pool.userItemIndexes[
                msg.sender
            ];

            for (uint i = 0; i < userStakeIndexes.length; i++) {
                uint256 itemIndex = userStakeIndexes[i];
                _restakeReward(index, itemIndex);
            }
        }

        emit RestakeRewardAll(msg.sender, _amount);
    }

    /**
     * @notice Return reward to user and reset stake item unlock time
     * @param _poolIndex pool index
     * @param _stakeItemIndex item index
     */
    function restake(
        uint256 _poolIndex,
        uint256 _stakeItemIndex
    ) external nonReentrant stopAllCheck(msg.sender) {
        StakePool storage pool = pools[_poolIndex];
        StakeItem storage stakeItem = pool.stakeItem[_stakeItemIndex];
        _restake(pool, stakeItem);

        emit Restake(
            _poolIndex,
            _stakeItemIndex,
            msg.sender,
            stakeItem.unlockTime
        );
    }

    /**
     * @notice Return reward to user in each pool and reset all stake items unlock time
     * @param _poolIndexes array of pool indexes
     */
    function restakeAll(
        uint256[] memory _poolIndexes
    ) external nonReentrant stopAllCheck(msg.sender) {
        for (uint i = 0; i < _poolIndexes.length; i++) {
            StakePool storage pool = pools[i];
            uint256[] memory userItemIndexes = pool.userItemIndexes[msg.sender];
            for (uint index = 0; index < userItemIndexes.length; index++) {
                uint256 itemIndex = userItemIndexes[index];
                StakeItem storage item = pool.stakeItem[itemIndex];
                if (item.remainingReward > 0) {
                    _restake(pool, item);
                }
            }
        }

        emit RestakeAll(_poolIndexes, msg.sender);
    }

    /**
     * @notice Submit withdraw transaction for confirming, only for treasury role
     * @param _tokenAddress withdraw token address
     * @param _amount amount of token submitter to withdraw
     */
    function submitTransaction(
        address _tokenAddress,
        uint256 _amount,
        bytes32 _transactionType,
        address _treasuryUserAddress,
        bool _userGranted,
        address _withdrawWallet
    ) external nonReentrant onlyTreasuryRole(TREASURY, msg.sender) {
        require(
            _transactionType == MULTISIG_TYPE_TREASURY ||
                _transactionType == MULTISIG_TYPE_WITHDRAW ||
                _transactionType == MULTISIG_TYPE_CHANGE_WALLET,
            "StakingPool: invalid transaction type"
        );

        uint256 txIndex = multisigTransactions.length;

        if (_transactionType == MULTISIG_TYPE_WITHDRAW) {
            require(
                _tokenAddress == address(stakingToken) ||
                    _tokenAddress == address(rewardsToken),
                "StakingPool: cannot withdraw token that not in the pool"
            );
            require(
                _amount > 0,
                "StakingPool: cannot submit transaction with zero amount"
            );
        } else if (_transactionType == MULTISIG_TYPE_TREASURY) {
            require(
                _treasuryUserAddress != address(0),
                "StakingPool: user address cannot be zero address"
            );
        } else {
            require(
                _withdrawWallet != address(0),
                "StakingPool: withdraw wallet cannot be zero address"
            );
        }

        multisigTransactions.push(
            Transaction({
                txIndex: multisigTransactions.length,
                executed: false,
                numConfirmations: 0,
                amount: _amount,
                submitter: msg.sender,
                tokenAddress: _tokenAddress,
                transactionType: _transactionType,
                treasuryUserAddress: _treasuryUserAddress,
                userGranted: _userGranted,
                withdrawWallet: _withdrawWallet,
                expiredAt: block.timestamp + 1 hours
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _transactionType);
    }

    /**
     * @notice Confirm withdraw transaction for execute, only for treasury role
     * @param _txIndex withdraw transaction index
     */
    function confirmTransaction(
        uint256 _txIndex
    )
        external
        nonReentrant
        onlyTreasuryRole(TREASURY, msg.sender)
        txExists(_txIndex)
        notExecuted(_txIndex)
        userNotConfirmed(_txIndex)
        notExpired(_txIndex)
    {
        Transaction storage transaction = multisigTransactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    /**
     * @notice Execute 1 transaction to withdraw token to caller, only for treasury role
     * @param _txIndex withdraw transaction index
     */
    function executeTransaction(
        uint256 _txIndex
    )
        external
        nonReentrant
        onlyTreasuryRole(TREASURY, msg.sender)
        txExists(_txIndex)
        confirmed(_txIndex)
        notExecuted(_txIndex)
        notExpired(_txIndex)
    {
        Transaction storage transaction = multisigTransactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "StakingPool: cannot execute tx, not enough confirmation"
        );

        transaction.executed = true;

        if (transaction.transactionType == MULTISIG_TYPE_WITHDRAW) {
            _withdrawRewardPool(transaction.tokenAddress, transaction.amount);

            emit WithdrawRewardPool(
                msg.sender,
                transaction.txIndex,
                transaction.amount
            );
        } else if (transaction.transactionType == MULTISIG_TYPE_TREASURY) {
            if (transaction.userGranted == true) {
                grantTreasuryRole(
                    TREASURY,
                    transaction.treasuryUserAddress,
                    msg.sender
                );
            } else {
                revokeTreasuryRole(
                    TREASURY,
                    transaction.treasuryUserAddress,
                    msg.sender
                );
            }
        } else {
            withdrawWallet = transaction.withdrawWallet;
            emit ChangeWithdrawWallet(
                transaction.withdrawWallet,
                transaction.txIndex
            );
        }
    }

    /**
     * @notice Revoke confirmation from 1 transaction, only for treasury role
     * @param _txIndex withdraw transaction index
     */
    function revokeConfirmation(
        uint256 _txIndex
    )
        external
        nonReentrant
        onlyRole(TREASURY)
        txExists(_txIndex)
        confirmed(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = multisigTransactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    /**
     * @notice Return token to all users
     */
    function stopEmergency(
        address[] memory _userAddressArr
    ) external nonReentrant onlyOwner {
        uint256 amount;

        for (uint256 poolIndex = 0; poolIndex < pools.length; poolIndex++) {
            StakePool storage pool = pools[poolIndex];
            for (uint256 i = 0; i < _userAddressArr.length; i++) {
                uint256[] storage itemIndexes = pool.userItemIndexes[
                    _userAddressArr[i]
                ];

                for (
                    uint256 itemIndex = 0;
                    itemIndex < itemIndexes.length;
                    itemIndex++
                ) {
                    StakeItem storage item = pool.stakeItem[itemIndex];
                    amount += item.stakedAmount;
                    stakingToken.transfer(
                        _userAddressArr[i],
                        item.stakedAmount
                    );
                    delete pool.stakeItem[itemIndex];
                    pool.totalStaked -= item.stakedAmount;
                }
            }
        }

        emit StopEmergency(_userAddressArr, amount);
    }

    /**
     * @notice Get total token staked
     */
    function getTotalStaked() public view returns (uint256) {
        uint256 totalTokenStaked;
        for (uint i = 0; i < pools.length; i++) {
            StakePool storage pool = pools[i];
            totalTokenStaked += pool.totalStaked;
        }

        return totalTokenStaked;
    }

    /**
     * @notice Get user stake item of pool
     */
    function getUserStakeItems(
        uint256 _poolIndex,
        address _userAddress
    ) public view returns (StakeItem[] memory) {
        StakePool storage pool = pools[_poolIndex];
        StakeItem[] memory items;
        uint256[] storage userItemIndexes = pool.userItemIndexes[_userAddress];

        items = new StakeItem[](userItemIndexes.length);
        for (uint i = 0; i < userItemIndexes.length; i++) {
            items[i] = pool.stakeItem[userItemIndexes[i]];
        }

        return items;
    }

    /**
     * @notice Get user stake amount in each pool
     * @param _userAddress user address
     * @param _poolIndexes array of pool index
     */
    function getUserStakes(
        address _userAddress,
        uint256[] memory _poolIndexes
    ) public view returns (UserPoolInfo[] memory) {
        UserPoolInfo[] memory userPoolInfo = new UserPoolInfo[](
            _poolIndexes.length
        );
        uint256 closestUnlockTime;

        for (uint i = 0; i < _poolIndexes.length; i++) {
            uint256 poolIndex = _poolIndexes[i];
            StakePool storage pool = pools[poolIndex];
            uint256 totalStaked = 0;
            uint256[] storage stakeItemIndexes = pool.userItemIndexes[
                _userAddress
            ];

            if (stakeItemIndexes.length > 0) {
                for (uint index = 0; index < stakeItemIndexes.length; index++) {
                    uint256 itemIndex = stakeItemIndexes[index];
                    StakeItem storage stakeItem = pool.stakeItem[itemIndex];

                    // total stake amount
                    if (stakeItem.unlockTime <= block.timestamp) {
                        totalStaked = totalStaked + stakeItem.stakedAmount;
                    }

                    // get closest unlock time
                    if (
                        stakeItem.userAddress == _userAddress &&
                        stakeItem.unlockTime > block.timestamp
                    ) {
                        if (closestUnlockTime == 0) {
                            closestUnlockTime = stakeItem.unlockTime;
                        } else {
                            if (stakeItem.unlockTime < closestUnlockTime) {
                                closestUnlockTime = stakeItem.unlockTime;
                            }
                        }
                    }
                    totalStaked = totalStaked + stakeItem.stakedAmount;
                }

                userPoolInfo[i] = UserPoolInfo(
                    poolIndex,
                    _userAddress,
                    totalStaked,
                    closestUnlockTime
                );
            }
        }

        return userPoolInfo;
    }

    /**
     * @notice Get stake item of pool
     * @param _poolIndex pool index
     * @param _itemIndex item index
     */
    function getStakeItem(
        uint256 _poolIndex,
        uint256 _itemIndex
    ) public view returns (StakeItem memory) {
        StakePool storage pool = pools[_poolIndex];

        return pool.stakeItem[_itemIndex];
    }

    /**
     * @notice Get size of transaction array
     */
    function getTransactionLength() public view returns (uint256) {
        return multisigTransactions.length;
    }

    function getAllStakedUsers() public view returns (address[] memory) {
        return stakedUsers;
    }

    function _createPool(
        uint256 _apyRate,
        uint256 _apyDecimals,
        uint256 _lockingPeriod
    ) private {
        uint256 poolIndex = pools.length;
        StakePool storage pool = pools.push(); // Create a new pool in storage
        pool.apy.rate = _apyRate;
        pool.apy.decimals = _apyDecimals;
        pool.lockPeriod = _lockingPeriod;
        pool.poolIndex = poolIndex;

        emit CreatePool(poolIndex, _apyRate, _apyDecimals, _lockingPeriod);
    }

    function _stake(
        uint256 _poolIndex,
        uint256 _stakeAmount,
        address _stakeAddress
    ) private {
        StakePool storage stakePool = pools[_poolIndex];
        require(!stakePool.paused, "StakingPool: Staking is paused");
        currentItemIndex = currentItemIndex + 1;
        uint256 stakeItemIndex = currentItemIndex;

        // create stake item
        StakeItem memory userStakeItem;
        userStakeItem.poolIndex = _poolIndex;
        userStakeItem.apy = stakePool.apy;
        userStakeItem.unlockTime = block.timestamp + stakePool.lockPeriod;
        userStakeItem.lastUpdatedTime = block.timestamp;
        userStakeItem.stakedAmount = _stakeAmount;
        userStakeItem.itemIndex = stakeItemIndex;
        userStakeItem.userAddress = _stakeAddress;
        userStakeItem.lockPeriod = stakePool.lockPeriod;

        if (stakePool.userItemIndexes[msg.sender].length == 0) {
            stakePool.totalUserStaked++;
        }
        stakePool.totalStaked = stakePool.totalStaked + _stakeAmount;

        bool userHasStaked;
        for (uint256 index = 0; index < stakedUsers.length; index++) {
            address userAddress = stakedUsers[index];
            if (userAddress == _stakeAddress) {
                userHasStaked = true;
            }
        }
        if (!userHasStaked) {
            stakedUsers.push(_stakeAddress);
        }

        // mapping stake item to pool
        stakePool.stakeItem[stakeItemIndex] = userStakeItem;
        stakePool.totalStakeItem++;

        // mapping stake item to user address
        stakePool.userItemIndexes[msg.sender].push(stakeItemIndex);

        stakingToken.transferFrom(_stakeAddress, address(this), _stakeAmount);
    }

    function _unstake(
        uint256 _poolIndex,
        StakeItem storage _stakeItem
    ) private {
        require(
            _stakeItem.userAddress == msg.sender,
            "StakingPool: This stake item belongs to another address"
        );
        StakePool storage stakePool = pools[_poolIndex];

        _updateRewardRemaining(_poolIndex, _stakeItem);
        stakePool.totalStaked = stakePool.totalStaked - _stakeItem.stakedAmount;
        stakePool.totalRewardClaimed += _stakeItem.remainingReward;
        _stakeItem.unlockTime = block.timestamp + stakePool.lockPeriod;
        _stakeItem.unstaked = true;

        stakingToken.transfer(msg.sender, _stakeItem.stakedAmount);
        rewardsToken.transfer(msg.sender, _stakeItem.remainingReward);

        // reset reward
        _stakeItem.remainingReward = 0;
    }

    function _restakeReward(
        uint256 _poolIndex,
        uint256 _stakeItemIndex
    ) private {
        StakePool storage pool = pools[_poolIndex];
        StakeItem storage stakeItem = pool.stakeItem[_stakeItemIndex];

        require(
            stakeItem.userAddress == msg.sender,
            "StakingPool: This stake item belongs to another address"
        );
        require(!pool.paused, "StakingPool: Restaking is paused");

        if (stakeItem.userAddress != address(0)) {
            _updateRewardRemaining(_poolIndex, stakeItem);

            stakeItem.stakedAmount =
                stakeItem.stakedAmount +
                stakeItem.remainingReward;
            pool.totalStaked = pool.totalStaked + stakeItem.remainingReward;
            stakeItem.remainingReward = 0;
        }
    }

    function _restake(
        StakePool storage pool,
        StakeItem storage stakeItem
    ) private {
        require(
            stakeItem.userAddress == msg.sender,
            "StakingPool: This stake item belongs to another address"
        );

        _updateRewardRemaining(pool.poolIndex, stakeItem);
        pool.totalRewardClaimed += stakeItem.remainingReward;
        stakeItem.unlockTime = block.timestamp + stakeItem.lockPeriod;
        rewardsToken.transfer(msg.sender, stakeItem.remainingReward);

        // reset reward
        stakeItem.remainingReward = 0;
    }

    function _claim(
        uint256 _poolIndex,
        StakeItem storage _stakeItem,
        StakePool storage _stakepool
    ) private {
        require(
            _stakeItem.userAddress == msg.sender,
            "StakingPool: This stake item belongs to another address"
        );
        _updateRewardRemaining(_poolIndex, _stakeItem);
        _stakepool.totalRewardClaimed += _stakeItem.remainingReward;
        rewardsToken.transfer(msg.sender, _stakeItem.remainingReward);

        emit Claim(
            _poolIndex,
            _stakeItem.itemIndex,
            msg.sender,
            _stakeItem.remainingReward,
            _stakepool.totalRewardClaimed
        );

        // reset reward
        _stakeItem.remainingReward = 0;
    }

    function _updateRewardRemaining(
        uint256 _poolIndex,
        StakeItem storage _stakeItem
    ) private {
        StakePool storage pool = pools[_poolIndex];
        require(pool.totalStaked > 0, "Staking: no reward to claim");

        uint256 currentTime = block.timestamp;
        uint256 timeElapsed = currentTime - _stakeItem.lastUpdatedTime;
        // maximum elapsed time = lock period, no reward counted after lock time ends
        if (timeElapsed > _stakeItem.lockPeriod) {
            timeElapsed = _stakeItem.lockPeriod;
        }
        uint256 rewardIncrease = (_stakeItem.stakedAmount *
            _stakeItem.apy.rate *
            timeElapsed) / (ONE_YEAR * 10 ** _stakeItem.apy.decimals);

        _stakeItem.remainingReward += rewardIncrease;
        _stakeItem.lastUpdatedTime = currentTime;
    }

    function _withdrawRewardPool(
        address _tokenAddress,
        uint256 _amount
    ) private {
        uint256 totalTokenStaked = getTotalStaked();

        require(
            _amount <= totalTokenStaked,
            "StakingPool: withdraw amount cannot be greater than total stake amount"
        );

        if (_tokenAddress == address(stakingToken)) {
            stakingToken.transfer(withdrawWallet, _amount);
        } else {
            rewardsToken.transfer(withdrawWallet, _amount);
        }
    }
}
