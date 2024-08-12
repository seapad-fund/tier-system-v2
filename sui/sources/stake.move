module seapad::stake {

    use std::vector;
    use sui::token::amount;
    use sui::zklogin_verified_id::owner;
    use sui::clock;
    use sui::clock::Clock;
    use sui::table::Table;
    use sui::event;
    use sui::transfer::share_object;
    use sui::coin;
    use seapad::version::{Version, checkVersion};
    use sui::transfer;
    use sui::object;
    use sui::tx_context::{TxContext, sender};
    use sui::object::{UID, id_address};
    use sui::table;
    use sui::coin::Coin;

    const ERR_BAD_FUND_PARAMS: u64 = 8001;
    const ERR_AMOUNT_CANNOT_BE_ZERO: u64 = 8002;
    const ERR_NO_FUND: u64 = 8003;
    const ERR_NO_STAKE: u64 = 8004;
    const ERR_NOT_ENOUGH_S_BALANCE: u64 = 8005;
    const ERR_TOO_EARLY_UNSTAKE: u64 = 8006;
    const ERR_NOTHING_TO_HARVEST: u64 = 8007;
    const ERR_PAUSED: u64 = 8008;
    const ERR_NO_UNSTAKE: u64 = 8009;
    const ERR_NO_REQUEST_FUND: u64 = 8010;
    const ERR_NO_CONFIRM_REQUEST: u64 = 8010;
    const ERR_NO_EXCUTE_REQUEST_FUND: u64 = 8011;
    const ERR_NO_REVOKE_REQUEST_FUND: u64 = 8012;
    const ERR_NO_EXCUTE_REQUEST_CHANGE_TREASURY: u64 = 8013;
    const ERR_NO_REVOKE_REQUEST_CHANGE_TREASURY: u64 = 8014;
    const ERR_NO_EXECUTE_REQUEST_CHANGE_VOTER: u64 = 8015;
    const ERR_NO_REQUEST_CHANGE_VOTER: u64 = 8016;
    const ERR_NO_REQUEST_CHANGE_TREASURY: u64 = 8017;
    const ERR_NO_REVOKE_REQUEST_CHANGE_VOTER: u64 = 8018;
    const ERR_AMOUNT_IS_NOT_ENOUGH: u64 = 8019;
    const ERR_VALUE_CANNOT_BE_ZERO: u64 = 8020;
    const ERR_NO_UPGRADE_POOL: u64 = 8021;
    const ERR_STOPPEDALL: u64 = 8022;
    const ERR_REQUESTID: u64 = 8023;

    const ONE_YEARS_MS: u64 = 31536000000;

    const ONE_HOURS_MS: u64 = 3600000;

    const TEN_DAYS_MS: u64 = 864000000;
    const SIXTY_DAYS_MS: u64 = 5184000000;
    const ONE_HUNDRED_EIGHTY_DAYS_MS: u64 = 15552000000;
    const THREE_HUNDRED_SIXTY_DAYS_MS: u64 = 31104000000;
    const VALUE_MIN_STAKE: u128 = 500;

    const VERSION: u64 = 1;

    struct STAKE has drop {}

    struct Admincap has store, key {
        id: UID,
    }

    struct StakePool<phantom S, phantom R> has key, store {
        id: UID,
        apy: u128,
        paused: bool,
        stopAll: bool,
        lock_period: u64,
        min_stake: u128,
        total_reward_claimed: u128,
        reward_coins: Coin<R>,
        stake_coins: Coin<S>,
        stakes: vector<address>
    }

    struct StakeItem has key, store {
        id: UID,
        pool: address,
        owner: address,
        apy: u128,
        staked_amount: u128,
        unstaked: bool,
        reward_remaining: u128,
        lastest_updated_time: u64,
        time_stake: u64,
        unlock_times: u64,
    }

    struct RegistryStakePool has key, store {
        id: UID,
        pools: Table<address, PoolInfo>,
        user_items: Table<address, vector<address>>
    }

    struct PoolInfo has drop, store, copy {
        id: address,
        rTypeCoin: vector<u8>,
        sTypeCoin: vector<u8>
    }

    struct UserStakePoolInfo has key, store {
        id: UID,
        users_staked: Table<address, PoolStakedInfo>
    }

    struct PoolStakedInfo has store {
        pools_staked: Table<address, u128>
    }

    struct RequestId has key, store {
        id: UID,
        request: vector<vector<u8>>
    }

    struct VaultDAO has key, store {
        id: UID,
        dao: Table<address, VoteInfo>,
        quorum: u8,
        num_confirmations_required: u8,
        treasury: address
    }

    struct VoteInfo has drop, store, copy {
        vote: bool
    }

    struct RequestFundInfo has key, store {
        id: UID,
        pool_id: address,
        request_creator: address,
        total_amount: u128,
        agree: u8,
        executed: bool,
        time_confirm: u64,
        voted: vector<address>
    }

    struct RequestChangeTreasuryInfo has key, store {
        id: UID,
        request_creator: address,
        agree: u8,
        executed: bool,
        time_confirm: u64,
        new_treasury_address: address,
        voted: vector<address>
    }

    struct RequestChangeVoterInfo has key, store {
        id: UID,
        request_creator: address,
        agree: u8,
        executed: bool,
        time_confirm: u64,
        new_address_voter: address,
        voted: vector<address>
    }

    struct RegistryRequest has key, store {
        id: UID,
        request_fund: vector<address>,
        request_treasury: vector<address>,
        request_change_voter: vector<address>
    }

    struct Providers has key, store {
        id: UID,
        providers_address: vector<address>
    }

    struct CreatePoolEvent has drop, copy {
        pool_id: address,
        apy: u128,
        lock_period: u64
    }

    struct StakeEvent has drop, store, copy {
        pool_id: address,
        owner: address,
        apy: u128,
        staked_amount: u128,
        stake_item_id: address,
        is_unstaked: bool,
        time_stake: u64,
        user_lastest_updated_time: u64,
        unlock_time: u64,
    }

    struct UnStakeEvent has drop, store, copy {
        pool_id: address,
        owner: address,
        staked_amount: u128,
        user_reward_remaining: u128,
        unlock_time: u64,
        stake_item_id: address,
        is_unstaked: bool,
        time_stake: u64
    }

    struct RestakeRewardEvent has drop, store, copy {
        pool_id: address,
        owner: address,
        staked_amount: u128,
        stake_item_id: address,
        is_unstaked: bool,
        time_stake: u64,
        unlock_time: u64,
    }

    struct MigrateStakeEvent has drop, store, copy {
        pool_id: address,
        stake_item_id: address,
        owner: address,
        unlock_time: u64,
        staked_amount: u128,
        is_unstaked: bool,
        time_stake: u64,
        reqId: vector<u8>
    }

    struct ClaimEvent has drop, store, copy {
        pool_id: address,
        user_address: address,
        amount_claimed: u128,
        stake_item_id: address
    }

    struct DepositRewardEvent has drop, store, copy {
        pool_id: address,
        amount: u128,
        total_reward: u128
    }

    struct WithdarawRewardEvent has drop, store, copy {
        pool_id: address,
        total_reward: u128
    }

    struct UpdateApyEvent has drop, store, copy {
        user_address: address,
        stake_item_id: address,
        apy: u128,
        user_reward_remaining: u128
    }

    struct StopEmergencyEvent has drop, store, copy {
        pool_id: address,
        total_staked: u128,
        paused: bool,
        stake_item_id: address
    }

    struct RequestFundEvent has drop, store, copy {
        pool_id: address,
        vault_id: address,
        member: address,
        total_amount: u128,
        total_agree: u8,
        time_confirm: u64
    }

    struct ConfirmRequest has drop, store, copy {
        vault_id: address,
        request_info_id: address,
        member: address,
        total_agree: u8,
    }

    struct ExecuteRequestFundEvent has drop, store, copy {
        pool_id: address,
        vault_id: address,
        request_info_id: address,
        member: address,
        total_agree: u8,
        total_amount: u128,
        executed: bool
    }

    struct RevokeConfirmationEvent  has drop, store, copy {
        vault_id: address,
        request_info_id: address,
        member: address,
        total_agree: u8,
    }

    struct RevokeRequestFundEvent has drop, store, copy {
        vault_id: address,
        request_info_id: address,
        member: address,
    }


    struct RequestChangeTreasuryEvent has drop, store, copy {
        vault_id: address,
        member: address,
        new_treasury: address,
        total_agree: u8,
        time_confirm: u64
    }

    struct ConfirmRequestChangeTreasuryEvent has drop, store, copy {
        vault_id: address,
        request_info_id: address,
        member: address,
        total_agree: u8,
    }

    struct ExecuteRequestChangeTreasuryEvent has drop, store, copy {
        vault_id: address,
        request_info_id: address,
        member: address,
        new_treasury: address,
        total_agree: u8,
    }

    struct RevokeConfirmationChangeTreasuryEvent has drop, store, copy {
        vault_id: address,
        request_info_id: address,
        member: address,
        total_agree: u8,
    }

    struct RevokeRequestChangeTreasuryEvent has drop, store, copy {
        vault_id: address,
        request_info_id: address,
        member: address,
    }

    struct RequestChangeVoterEvent has drop, store, copy {
        vault_id: address,
        member: address,
        new_address_voter: address,
        total_agree: u8,
        time_confirm: u64
    }

    struct ConfirmRequestChangeVoteEvent has drop, store, copy {
        vault_id: address,
        request_info_id: address,
        member: address,
        total_agree: u8,
    }

    struct ExecuteRequestChangeVoterEvent has drop, store, copy {
        vault_id: address,
        request_info_id: address,
        member: address,
        new_address_voter: address,
        total_agree: u8,
    }

    struct RevokeRequestChangeVoterEvent has drop, store, copy {
        vault_id: address,
        request_info_id: address,
        member: address,
    }

    struct UpdateLockPeriodEvent has drop, store, copy {
        pool_id: address,
        value: u64
    }

    struct UpdateApyPool has drop, store, copy {
        pool_id: address,
        apy: u128
    }

    struct UpdateMinStakeEvent has drop, store, copy {
        pool_id: address,
        value: u128
    }

    struct UpgradeStakeItem has drop, store, copy {
        pool_id_old: address,
        pool_id_new: address,
        user_address: address,
        stake_item_id: address,
        staked_mount: u128,
        apy: u128,
        unlock_time: u128
    }

    struct AddProviderEvent has drop, store, copy {
        provider_id: address,
        provider_mem_address: address
    }

    struct RemoveProviderEvent has drop, store, copy {
        provider_id: address,
        provider_mem_address: address
    }

    struct Restake has drop, store, copy {
        pool_id: address,
        owner: address,
        staked_amount: u128,
        stake_item_id: address,
        is_unstaked: bool,
        time_stake: u64,
        unlock_time: u64,
    }


    fun init(_witness: STAKE, ctx: &mut TxContext) {
        let adminCap = Admincap { id: object::new(ctx) };
        transfer::transfer(adminCap, sender(ctx));

        share_object(RegistryStakePool {
            id: object::new(ctx),
            pools: table::new(ctx),
            user_items: table::new(ctx)
        });

        share_object(RegistryRequest {
            id: object::new(ctx),
            request_fund: vector::empty(),
            request_treasury: vector::empty(),
            request_change_voter: vector::empty()
        });

        share_object(Providers {
            id: object::new(ctx),
            providers_address: vector::empty<address>()
        });

        share_object(UserStakePoolInfo {
            id: object::new(ctx),
            users_staked: table::new<address, PoolStakedInfo>(ctx)
        });

        share_object(RequestId {
            id: object::new(ctx),
            request: vector::empty<vector<u8>>()
        });

        let vault = VaultDAO {
            id: object::new(ctx),
            dao: table::new<address, VoteInfo>(ctx),
            quorum: 3,
            num_confirmations_required: 2,
            treasury: @treasury_test
        };

        let vote_info = VoteInfo {
            vote: false
        };

        table::add(&mut vault.dao, @acc_1, vote_info);
        table::add(&mut vault.dao, @acc_2, vote_info);
        table::add(&mut vault.dao, @acc_3, vote_info);

        transfer::share_object(vault);
    }

    public entry fun change_admin(adminCap: Admincap,
                                  to: address,
                                  version: &mut Version) {
        checkVersion(version, VERSION);
        transfer::public_transfer(adminCap, to);
    }

    public entry fun pause<S, R>(_admin: &Admincap, pool: &mut StakePool<S, R>, version: &mut Version) {
        checkVersion(version, VERSION);
        pool.paused = true;
    }

    public entry fun unPause<S, R>(_admin: &Admincap, pool: &mut StakePool<S, R>, version: &mut Version) {
        checkVersion(version, VERSION);
        assert!(pool.paused == true, ERR_NO_FUND);
        pool.paused = false;
    }

    public entry fun stopAll<S, R>(_admin: &Admincap, pool: &mut StakePool<S, R>, version: &mut Version) {
        checkVersion(version, VERSION);
        pool.stopAll = true;
    }

    public entry fun unStopAll<S, R>(_admin: &Admincap, pool: &mut StakePool<S, R>, version: &mut Version) {
        checkVersion(version, VERSION);
        assert!(pool.stopAll == true, ERR_NO_FUND);
        pool.stopAll = false;
    }

    public entry fun addProvider(
        _admin: &Admincap,
        provider: &mut Providers,
        provider_new_address: address,
        version: &mut Version
    ) {
        checkVersion(version, VERSION);
        let (exist, _index) = vector::index_of(&provider.providers_address, &provider_new_address);
        if (!exist) {
            vector::push_back(&mut provider.providers_address, provider_new_address);
        };

        event::emit(AddProviderEvent {
            provider_id: id_address(provider),
            provider_mem_address: provider_new_address
        });
    }


    public entry fun removeProvider(
        _admin: &Admincap,
        provider: &mut Providers,
        provider_address: address,
        version: &mut Version
    ) {
        checkVersion(version, VERSION);
        let (exist, index) = vector::index_of(&provider.providers_address, &provider_address);
        if (exist) {
            vector::remove(&mut provider.providers_address, index);
        };

        event::emit(RemoveProviderEvent {
            provider_id: id_address(provider),
            provider_mem_address: provider_address
        });
    }

    public entry fun createPool<S, R>(
        _admin: &Admincap,
        apy: u128,
        lock_period: u64,
        user_item_indexes: &mut RegistryStakePool,
        rTypeCoin: vector<u8>,
        sTypeCoin: vector<u8>,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        assert!(apy > 0u128 && lock_period > 0, ERR_BAD_FUND_PARAMS);

        let pool = StakePool<S, R> {
            id: object::new(ctx),
            apy,
            paused: false,
            stopAll: false,
            lock_period,
            min_stake: VALUE_MIN_STAKE,
            total_reward_claimed: 0,
            stake_coins: coin::zero(ctx),
            reward_coins: coin::zero(ctx),
            stakes: vector::empty<address>()
        };

        let poolId = id_address(&pool);

        let pool_info = PoolInfo {
            id: poolId,
            rTypeCoin,
            sTypeCoin
        };

        table::add(&mut user_item_indexes.pools, poolId, pool_info);

        event::emit(CreatePoolEvent {
            pool_id: poolId,
            apy,
            lock_period
        });

        share_object(pool);
    }

    /// Stakes user coins in pool.
    public fun stake<S, R>(
        pool: &mut StakePool<S, R>,
        coins: Coin<S>,
        sclock: &Clock,
        user_item_indexes: &mut RegistryStakePool,
        user_info_pool: &mut UserStakePoolInfo,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        assert!(!pool.paused, ERR_PAUSED);
        assert!(!pool.stopAll, ERR_STOPPEDALL);
        let now = clock::timestamp_ms(sclock);
        let stake_amount = (coin::value(&coins) as u128);
        assert!(stake_amount > 0u128, ERR_AMOUNT_CANNOT_BE_ZERO);
        assert!(stake_amount >= pool.min_stake, ERR_AMOUNT_IS_NOT_ENOUGH);

        let user_address = sender(ctx);
        let apy_pool = pool.apy;
        let pool_id = id_address(pool);

        let user_stake_item = StakeItem {
            id: object::new(ctx),
            pool: pool_id,
            owner: user_address,
            apy: apy_pool,
            staked_amount: stake_amount,
            unstaked: false,
            reward_remaining: 0,
            lastest_updated_time: now,
            time_stake: now,
            unlock_times: now + pool.lock_period
        };

        let stake_items_id = id_address(&user_stake_item);

        let (exist, _index) = vector::index_of(&pool.stakes, &user_address);
        if (!exist) {
            vector::push_back(&mut pool.stakes, user_address);
        };

        addRegistryStakePool(user_item_indexes, user_address, stake_items_id);

        coin::join(&mut pool.stake_coins, coins);


        if (!table::contains(&mut user_info_pool.users_staked, user_address)) {
            let staked_info = PoolStakedInfo {
                pools_staked: table::new(ctx)
            };
            table::add(&mut staked_info.pools_staked, pool_id, stake_amount);
            table::add(&mut user_info_pool.users_staked, user_address, staked_info);
        }else {
            let info_staked = table::borrow_mut(&mut user_info_pool.users_staked, user_address);

            if (table::contains(&mut info_staked.pools_staked, pool_id)) {
                let user_staked_in_pool = *table::borrow_mut(&mut info_staked.pools_staked, pool_id);
                let user_staked_new_in_pool = stake_amount + user_staked_in_pool;
                table::remove(&mut info_staked.pools_staked, pool_id);

                table::add(&mut info_staked.pools_staked, pool_id, user_staked_new_in_pool)
            }else {
                table::add(&mut info_staked.pools_staked, pool_id, stake_amount);
            }
        };

        event::emit(StakeEvent {
            pool_id,
            owner: user_address,
            apy: apy_pool,
            staked_amount: stake_amount,
            stake_item_id: id_address(&user_stake_item),
            is_unstaked: false,
            time_stake: now,
            user_lastest_updated_time: now,
            unlock_time: now + pool.lock_period,
        });
        transfer::share_object(user_stake_item);
    }

    public fun upgradeStakeItem<S, R>(
        pool_old: &mut StakePool<S, R>,
        pool_new: &mut StakePool<S, R>,
        stake_items_id: &mut StakeItem,
        user_item_indexes: &mut RegistryStakePool,
        sclock: &Clock,
        user_info_pool: &mut UserStakePoolInfo,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        assert!(!pool_new.paused, ERR_PAUSED);
        assert!(!pool_new.stopAll, ERR_STOPPEDALL);
        assert!(!pool_old.stopAll, ERR_STOPPEDALL);
        assert!(pool_new.lock_period > pool_old.lock_period, ERR_NO_UPGRADE_POOL);

        let now = clock::timestamp_ms(sclock);
        let user_address = sender(ctx);

        claim(pool_old, stake_items_id, user_item_indexes, sclock, version, ctx);

        let apy_pool_new = pool_new.apy;
        let pool_id_new = id_address(pool_new);
        let staked_old = stake_items_id.staked_amount;

        let info_staked = table::borrow_mut(&mut user_info_pool.users_staked, user_address);
        if (!table::contains(&mut info_staked.pools_staked, pool_id_new) && now <= stake_items_id.unlock_times) {
            table::add(&mut info_staked.pools_staked, pool_id_new, staked_old);
        }else {
            let user_staked_in_pool_new = *table::borrow_mut(&mut info_staked.pools_staked, id_address(pool_new));
            let user_staked_new_in_pool_new = staked_old + user_staked_in_pool_new;
            table::remove(&mut info_staked.pools_staked, pool_id_new);

            table::add(&mut info_staked.pools_staked, pool_id_new, user_staked_new_in_pool_new);
        };

        if (now <= stake_items_id.unlock_times) {
            let user_staked_in_pool_old = *table::borrow_mut(&mut info_staked.pools_staked, id_address(pool_old));
            let user_staked_new_in_pool_old = user_staked_in_pool_old - staked_old ;
            table::remove(&mut info_staked.pools_staked, id_address(pool_old));

            table::add(&mut info_staked.pools_staked, id_address(pool_old), user_staked_new_in_pool_old);
        };

        if (now < stake_items_id.unlock_times) {
            let bonus_Locked_Time = now - stake_items_id.time_stake;
            stake_items_id.unlock_times = (now + pool_new.lock_period) - bonus_Locked_Time;
        } else {
            let bonus_Locked_Time = pool_old.lock_period;
            stake_items_id.unlock_times = (now + pool_new.lock_period) - bonus_Locked_Time;
        };
        stake_items_id.pool = pool_id_new;
        stake_items_id.apy = apy_pool_new;
        stake_items_id.owner = user_address;
        stake_items_id.lastest_updated_time = now;
        stake_items_id.time_stake = now;

        let staked_amount = coin::split(&mut pool_old.stake_coins, (staked_old as u64), ctx);

        coin::join(&mut pool_new.stake_coins, staked_amount);

        let (exist, _index) = vector::index_of(&pool_new.stakes, &user_address);
        if (!exist) {
            vector::push_back(&mut pool_new.stakes, user_address);
        };

        event::emit(UpgradeStakeItem {
            pool_id_old: id_address(pool_old),
            pool_id_new,
            user_address,
            stake_item_id: id_address(stake_items_id),
            staked_mount: stake_items_id.staked_amount,
            apy: pool_new.apy,
            unlock_time: (stake_items_id.unlock_times as u128)
        });
    }

    public fun unstake<S, R>(
        pool: &mut StakePool<S, R>,
        sclock: &Clock,
        stake_items_id: &mut StakeItem,
        user_item_indexes: &mut RegistryStakePool,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        assert!(!pool.stopAll, ERR_STOPPEDALL);
        let now = clock::timestamp_ms(sclock);
        let user_address = sender(ctx);
        let pool_id = id_address(pool);
        let pool_id_in_stake_item = stake_items_id.pool;
        let user_address_in_stake_item = stake_items_id.owner;

        assert!(vector::contains(&pool.stakes, &user_address), ERR_NO_UNSTAKE);
        assert!(table::contains(&user_item_indexes.user_items, user_address), ERR_BAD_FUND_PARAMS);
        assert!(table::contains(&user_item_indexes.pools, pool_id), ERR_BAD_FUND_PARAMS);
        assert!(pool_id_in_stake_item == pool_id, ERR_BAD_FUND_PARAMS);
        assert!(user_address_in_stake_item == user_address, ERR_BAD_FUND_PARAMS);


        assert!(now >= stake_items_id.unlock_times, ERR_TOO_EARLY_UNSTAKE);
        let apy_stakeItem = stake_items_id.apy;

        update_reward_remaining(apy_stakeItem, now, stake_items_id);

        pool.total_reward_claimed = pool.total_reward_claimed + stake_items_id.reward_remaining;


        let value = (coin::value(&pool.reward_coins) as u128);
        let reward = stake_items_id.reward_remaining;
        assert!(reward > 0u128 && value >= reward, ERR_NO_FUND);

        stake_items_id.reward_remaining = 0;

        let reward = coin::split(&mut pool.reward_coins, (reward as u64), ctx);

        transfer::public_transfer(reward, user_address);

        let value = (coin::value(&pool.stake_coins) as u128);
        let amount = stake_items_id.staked_amount;
        assert!(value > 0 && value >= amount, ERR_NOT_ENOUGH_S_BALANCE);

        stake_items_id.unstaked = true;

        let coin = coin::split(&mut pool.stake_coins, (amount as u64), ctx);

        transfer::public_transfer(coin, user_address);

        event::emit(UnStakeEvent {
            pool_id: object::id_address(pool),
            owner: user_address,
            staked_amount: amount,
            user_reward_remaining: stake_items_id.reward_remaining,
            unlock_time: stake_items_id.unlock_times,
            is_unstaked: stake_items_id.unstaked,
            time_stake: stake_items_id.time_stake,
            stake_item_id: object::id_address(stake_items_id)
        });
    }


    public entry fun reStakeRewards<S, R>(
        pool: &mut StakePool<S, R>,
        stake_items_id: &mut StakeItem,
        user_item_indexes: &mut RegistryStakePool,
        user_info_pool: &mut UserStakePoolInfo,
        version: &mut Version,
        sclock: &Clock,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        assert!(!pool.paused, ERR_PAUSED);
        assert!(!pool.stopAll, ERR_STOPPEDALL);
        let now = clock::timestamp_ms(sclock);
        let user_address = sender(ctx);
        let pool_id = id_address(pool);
        let pool_id_in_stake_item = stake_items_id.pool;
        let user_address_in_stake_item = stake_items_id.owner;

        assert!(vector::contains(&pool.stakes, &user_address), ERR_BAD_FUND_PARAMS);
        assert!(table::contains(&user_item_indexes.user_items, user_address), ERR_BAD_FUND_PARAMS);
        assert!(table::contains(&user_item_indexes.pools, pool_id), ERR_BAD_FUND_PARAMS);
        assert!(pool_id_in_stake_item == pool_id, ERR_BAD_FUND_PARAMS);
        assert!(user_address_in_stake_item == user_address, ERR_BAD_FUND_PARAMS);

        let apy_stakeItem = stake_items_id.apy;

        update_reward_remaining(apy_stakeItem, now, stake_items_id);

        let value = stake_items_id.reward_remaining;
        assert!(value > 0, ERR_VALUE_CANNOT_BE_ZERO);
        stake_items_id.staked_amount = stake_items_id.staked_amount + value;

        stake_items_id.reward_remaining = 0;

        if (now <= stake_items_id.unlock_times) {
            let info_staked = table::borrow_mut(&mut user_info_pool.users_staked, user_address);
            let user_staked_in_pool = *table::borrow_mut(&mut info_staked.pools_staked, pool_id);
            let user_staked_new_in_pool = user_staked_in_pool + value ;
            table::remove(&mut info_staked.pools_staked, pool_id);

            table::add(&mut info_staked.pools_staked, pool_id, user_staked_new_in_pool);
        };

        event::emit(RestakeRewardEvent {
            pool_id: object::id_address(pool),
            owner: user_address,
            staked_amount: stake_items_id.staked_amount,
            stake_item_id: object::id_address(stake_items_id),
            is_unstaked: stake_items_id.unstaked,
            time_stake: stake_items_id.time_stake,
            unlock_time: stake_items_id.unlock_times
        });
    }

    public entry fun restake<S, R>(
        pool: &mut StakePool<S, R>,
        stake_items_id: &mut StakeItem,
        user_item_indexes: &mut RegistryStakePool,
        version: &mut Version,
        sclock: &Clock,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        assert!(!pool.paused, ERR_PAUSED);
        assert!(!pool.stopAll, ERR_STOPPEDALL);
        let now = clock::timestamp_ms(sclock);
        claim(pool, stake_items_id, user_item_indexes, sclock, version, ctx);

        stake_items_id.unlock_times = now + pool.lock_period;

        event::emit(Restake {
            pool_id: id_address(pool),
            stake_item_id: id_address(stake_items_id),
            owner: sender(ctx),
            unlock_time: stake_items_id.unlock_times,
            staked_amount: stake_items_id.staked_amount,
            time_stake: stake_items_id.time_stake,
            is_unstaked: stake_items_id.unstaked
        });
    }


    public entry fun migrateStake<S, R>(
        provider: &mut Providers,
        pool: &mut StakePool<S, R>,
        user_item_indexes: &mut RegistryStakePool,
        user_info_pool: &mut UserStakePoolInfo,
        request_id: &mut RequestId,
        _reqId: vector<u8>,
        user_address: address,
        coins: Coin<S>,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        assert!(!pool.paused, ERR_PAUSED);

        let user_call = sender(ctx);

        assert!(vector::contains(&provider.providers_address, &user_call), ERR_BAD_FUND_PARAMS);

        assert!(!vector::contains(&request_id.request, &_reqId), ERR_REQUESTID);

        vector::push_back(&mut request_id.request, _reqId);

        let now = clock::timestamp_ms(sclock);
        let stake_amount = (coin::value(&coins) as u128);
        assert!(stake_amount > 0u128, ERR_AMOUNT_CANNOT_BE_ZERO);

        let apy_pool = pool.apy;

        let pool_id = id_address(pool);

        let user_stake_item = StakeItem {
            id: object::new(ctx),
            pool: pool_id,
            owner: user_address,
            apy: apy_pool,
            staked_amount: stake_amount,
            unstaked: false,
            reward_remaining: 0,
            lastest_updated_time: now,
            time_stake: now,
            unlock_times: now + pool.lock_period
        };

        let stake_items_id = id_address(&user_stake_item);

        let (exist, _index) = vector::index_of(&pool.stakes, &user_address);
        if (!exist) {
            vector::push_back(&mut pool.stakes, user_address);
        };

        addRegistryStakePool(user_item_indexes, user_address, stake_items_id);

        coin::join(&mut pool.stake_coins, coins);

        if (!table::contains(&mut user_info_pool.users_staked, user_address)) {
            let staked_info = PoolStakedInfo {
                pools_staked: table::new(ctx)
            };
            table::add(&mut staked_info.pools_staked, pool_id, stake_amount);
            table::add(&mut user_info_pool.users_staked, user_address, staked_info);
        }else {
            let info_staked = table::borrow_mut(&mut user_info_pool.users_staked, user_address);

            if (table::contains(&mut info_staked.pools_staked, pool_id)) {
                let user_staked_in_pool = *table::borrow_mut(&mut info_staked.pools_staked, pool_id);
                let user_staked_new_in_pool = stake_amount + user_staked_in_pool;
                table::remove(&mut info_staked.pools_staked, pool_id);

                table::add(&mut info_staked.pools_staked, pool_id, user_staked_new_in_pool)
            }else {
                table::add(&mut info_staked.pools_staked, pool_id, stake_amount);
            }
        };

        event::emit(MigrateStakeEvent {
            pool_id: object::id_address(pool),
            stake_item_id: stake_items_id,
            owner: user_address,
            staked_amount: stake_amount,
            time_stake: now,
            is_unstaked: false,
            unlock_time:(now + pool.lock_period),
            reqId: _reqId
        });

        share_object(user_stake_item);
    }

    public entry fun claim<S, R>(
        pool: &mut StakePool<S, R>,
        stake_items_id: &mut StakeItem,
        user_item_indexes: &mut RegistryStakePool,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        assert!(!pool.stopAll, ERR_STOPPEDALL);
        let now = clock::timestamp_ms(sclock);
        let user_address = sender(ctx);
        let pool_id = id_address(pool);
        let pool_id_in_stake_item = stake_items_id.pool;
        let user_address_in_stake_item = stake_items_id.owner;

        assert!(vector::contains(&pool.stakes, &user_address), ERR_BAD_FUND_PARAMS);
        assert!(table::contains(&user_item_indexes.user_items, user_address), ERR_BAD_FUND_PARAMS);
        assert!(table::contains(&user_item_indexes.pools, pool_id), ERR_BAD_FUND_PARAMS);
        assert!(pool_id_in_stake_item == pool_id, ERR_BAD_FUND_PARAMS);
        assert!(user_address_in_stake_item == user_address, ERR_BAD_FUND_PARAMS);


        update_reward_remaining(stake_items_id.apy, now, stake_items_id);

        pool.total_reward_claimed = pool.total_reward_claimed + stake_items_id.reward_remaining;

        let value = (coin::value(&pool.reward_coins) as u128);
        let reward = stake_items_id.reward_remaining;
        assert!(reward > 0u128 && value >= reward, ERR_NO_FUND);

        stake_items_id.reward_remaining = 0;

        let reward = coin::split(&mut pool.reward_coins, (reward as u64), ctx);

        transfer::public_transfer(reward, user_address);

        event::emit(ClaimEvent {
            pool_id: object::id_address(pool),
            user_address,
            amount_claimed: value,
            stake_item_id: object::id_address(stake_items_id)
        });
    }

    public entry fun stopEmergency<S, R>(
        _admin: &Admincap,
        pool: &mut StakePool<S, R>,
        stake_items_id: &mut StakeItem,
        user_item_indexes: &mut RegistryStakePool,
        user_info_pool: &mut UserStakePoolInfo,
        owner: address,
        paused: bool,
        version: &mut Version,
        sclock: &Clock,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        let now = clock::timestamp_ms(sclock);
        let pool_id = id_address(pool);
        let pool_id_in_stake_item = stake_items_id.pool;
        let user_address_in_stake_item = stake_items_id.owner;

        assert!(vector::contains(&pool.stakes, &owner), ERR_BAD_FUND_PARAMS);
        assert!(table::contains(&user_item_indexes.user_items, owner), ERR_BAD_FUND_PARAMS);
        assert!(table::contains(&user_item_indexes.pools, pool_id), ERR_BAD_FUND_PARAMS);
        assert!(pool_id_in_stake_item == pool_id, ERR_BAD_FUND_PARAMS);
        assert!(user_address_in_stake_item == owner, ERR_BAD_FUND_PARAMS);

        let staked = stake_items_id.staked_amount;
        let value = (coin::value(&pool.stake_coins) as u128);
        assert!(staked > 0u128 && staked <= value, ERR_NO_FUND);

        stake_items_id.staked_amount = 0;

        let coin = coin::split(&mut pool.stake_coins, (staked as u64), ctx);

        transfer::public_transfer(coin, owner);

        pool.paused = paused;

        if (now <= stake_items_id.unlock_times) {
            let info_staked = table::borrow_mut(&mut user_info_pool.users_staked, owner);
            let user_staked_in_pool = *table::borrow_mut(&mut info_staked.pools_staked, pool_id);
            let user_staked_new_in_pool = user_staked_in_pool - staked ;
            table::remove(&mut info_staked.pools_staked, pool_id);

            table::add(&mut info_staked.pools_staked, pool_id, user_staked_new_in_pool);
        };

        event::emit(StopEmergencyEvent {
            pool_id,
            total_staked: (coin::value(&pool.stake_coins) as u128),
            paused,
            stake_item_id: object::id_address(stake_items_id)
        });
    }

    public entry fun updateApyStakeItem(
        _admin: &Admincap,
        apy: u128,
        owner: address,
        stake_items_id: &mut StakeItem,
        user_item_indexes: &mut RegistryStakePool,
        sclock: &Clock,
        version: &mut Version,
    ) {
        checkVersion(version, VERSION);

        let now = clock::timestamp_ms(sclock);
        let user_address_in_stake_item = stake_items_id.owner;

        assert!(table::contains(&user_item_indexes.user_items, owner), ERR_BAD_FUND_PARAMS);
        assert!(user_address_in_stake_item == owner, ERR_BAD_FUND_PARAMS);


        update_reward_remaining(stake_items_id.apy, now, stake_items_id);

        stake_items_id.apy = apy;

        event::emit(UpdateApyEvent {
            user_address: owner,
            stake_item_id: id_address(stake_items_id),
            apy,
            user_reward_remaining: stake_items_id.reward_remaining
        });
    }

    public entry fun updateApyPool<S, R>(
        _admin: &Admincap,
        pool: &mut StakePool<S, R>,
        apy: u128,
        version: &mut Version,
    ) {
        checkVersion(version, VERSION);
        assert!(apy > 0, ERR_BAD_FUND_PARAMS);
        pool.apy = apy;

        event::emit(UpdateApyPool {
            pool_id: id_address(pool),
            apy
        });
    }

    public entry fun updateLockPeriod<S, R>(
        _admin: &Admincap,
        pool: &mut StakePool<S, R>,
        lock_period: u64,
        version: &mut Version,
    ) {
        checkVersion(version, VERSION);
        assert!(lock_period > 0, ERR_BAD_FUND_PARAMS);
        pool.lock_period = lock_period;

        event::emit(UpdateLockPeriodEvent {
            pool_id: id_address(pool),
            value: lock_period
        });
    }

    public entry fun updateMinStake<S, R>(
        _admin: &Admincap,
        pool: &mut StakePool<S, R>,
        value: u128,
        version: &mut Version,
    ) {
        checkVersion(version, VERSION);
        assert!(value > 0u128, ERR_BAD_FUND_PARAMS);
        pool.min_stake = value;

        event::emit(UpdateMinStakeEvent {
            pool_id: id_address(pool),
            value
        });
    }

    /// Depositing reward coins to specific pool
    public entry fun depositRewardCoins<S, R>(
        _admin: &Admincap,
        pool: &mut StakePool<S, R>,
        version: &mut Version,
        coins: Coin<R>
    ) {
        checkVersion(version, VERSION);
        let amount = (coin::value(&coins) as u128);
        assert!(amount > 0u128, ERR_AMOUNT_CANNOT_BE_ZERO);

        coin::join(&mut pool.reward_coins, coins);

        event::emit(
            DepositRewardEvent {
                pool_id: object::id_address(pool),
                amount,
                total_reward: (coin::value(&pool.reward_coins) as u128)
            }
        );
    }

    /// Withdraw reward coins to specific pool
    fun withdrawRewardCoins<S, R>(
        vault: &mut VaultDAO,
        request_info: &mut RequestFundInfo,
        pool: &mut StakePool<S, R>,
        ctx: &mut TxContext
    ) {
        let value = (coin::value(&pool.reward_coins) as u128);
        let total_amout = request_info.total_amount;
        assert!(value > 0u128 && total_amout <= value, ERR_NO_FUND);
        let coin = coin::split(&mut pool.reward_coins, (value as u64), ctx);
        transfer::public_transfer(coin, vault.treasury);

        event::emit(WithdarawRewardEvent {
            pool_id: object::id_address(pool),
            total_reward: value
        });
    }

    fun update_reward_remaining(
        apy: u128,
        now: u64,
        user_stake: &mut StakeItem) {
        assert!(apy > 0u128, ERR_BAD_FUND_PARAMS);
        let time_max = user_stake.unlock_times;
        if (now >= time_max) {
            let time_diff = ((time_max - user_stake.lastest_updated_time) as u128);
            if (time_diff >= 0) {
                let reward_increase = ((time_diff * user_stake.staked_amount * apy) / (ONE_YEARS_MS * 10000 as u128));

                user_stake.reward_remaining = user_stake.reward_remaining + reward_increase;

                user_stake.lastest_updated_time = now;
            }
        } else {
            let time_diff = ((now - user_stake.lastest_updated_time) as u128);

            let reward_increase = ((time_diff * user_stake.staked_amount * apy) / (ONE_YEARS_MS * 10000 as u128));

            user_stake.reward_remaining = user_stake.reward_remaining + reward_increase;

            user_stake.lastest_updated_time = now;
        }
    }


    //Member create request withdraw fund
    public entry fun requestFund<S, R>(
        pool: &mut StakePool<S, R>,
        vault: &mut VaultDAO,
        registry_pool: &mut RegistryStakePool,
        registry_request: &mut RegistryRequest,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        let member_address = sender(ctx);
        let now = clock::timestamp_ms(sclock);
        let pool_id = id_address(pool);

        assert!(table::contains(&mut registry_pool.pools, pool_id), ERR_NO_FUND);

        let value = (coin::value(&pool.reward_coins) as u128);

        assert!(value > 0u128, ERR_NO_FUND);

        assert!(table::contains(&mut vault.dao, member_address), ERR_NO_REQUEST_FUND);

        let vote = table::borrow_mut(&mut vault.dao, member_address);

        vote.vote = true;

        let pool_id = id_address(pool);

        let request_info = RequestFundInfo {
            id: object::new(ctx),
            pool_id,
            request_creator: member_address,
            total_amount: value,
            agree: 1,
            executed: false,
            time_confirm: now + ONE_HOURS_MS,
            voted: vector::empty()
        };

        let request_id = id_address(&request_info);

        vector::push_back(&mut request_info.voted, member_address);

        vector::push_back(&mut registry_request.request_fund, request_id);

        event::emit(RequestFundEvent {
            pool_id: id_address(pool),
            vault_id: id_address(vault),
            member: sender(ctx),
            total_amount: request_info.total_amount,
            total_agree: request_info.agree,
            time_confirm: request_info.time_confirm
        });
        transfer::share_object(request_info);
    }


    //Member in vault confirm request.
    public entry fun confirmRequestFund(
        vault: &mut VaultDAO,
        request_info: &mut RequestFundInfo,
        registry_request: &mut RegistryRequest,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        let member_address = sender(ctx);
        let now = clock::timestamp_ms(sclock);
        let request_info_id = id_address(request_info);


        assert!(table::contains(&mut vault.dao, member_address), ERR_NO_CONFIRM_REQUEST);

        assert!(vector::contains(&mut registry_request.request_fund, &request_info_id), ERR_NO_FUND);

        assert!(!vector::contains(&mut request_info.voted, &member_address), ERR_NO_CONFIRM_REQUEST);

        assert!(request_info.time_confirm >= now, ERR_NO_CONFIRM_REQUEST);

        let vote = table::borrow_mut(&mut vault.dao, member_address);
        vote.vote = true;

        request_info.agree = request_info.agree + 1;

        vector::push_back(&mut request_info.voted, member_address);

        event::emit(ConfirmRequest {
            vault_id: id_address(vault),
            request_info_id: id_address(request_info),
            member: member_address,
            total_agree: request_info.agree,
        });
    }

    //Member execute request fund
    public entry fun executeRequestFund<S, R>(
        pool: &mut StakePool<S, R>,
        request_info: &mut RequestFundInfo,
        registry_request: &mut RegistryRequest,
        vault: &mut VaultDAO,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        let member_address = sender(ctx);
        let now = clock::timestamp_ms(sclock);
        let pool_id = id_address(pool);

        let request_info_id = id_address(request_info);

        assert!(table::contains(&mut vault.dao, member_address), ERR_NO_EXCUTE_REQUEST_FUND);

        assert!(vector::contains(&mut registry_request.request_fund, &request_info_id), ERR_NO_FUND);

        assert!(now <= request_info.time_confirm, ERR_NO_EXCUTE_REQUEST_FUND);

        let vote = table::borrow_mut(&mut vault.dao, member_address);
        assert!(vote.vote == true, ERR_NO_EXCUTE_REQUEST_FUND);
        assert!(vector::contains(&mut request_info.voted, &member_address), ERR_NO_EXCUTE_REQUEST_FUND);

        assert!(pool_id == request_info.pool_id, ERR_NO_EXCUTE_REQUEST_FUND);

        assert!(request_info.agree >= vault.num_confirmations_required, ERR_NO_EXCUTE_REQUEST_FUND);

        request_info.executed = true;

        withdrawRewardCoins<S, R>(vault, request_info, pool, ctx);

        event::emit(ExecuteRequestFundEvent {
            pool_id: id_address(pool),
            vault_id: id_address(vault),
            request_info_id: id_address(request_info),
            member: member_address,
            total_amount: request_info.total_amount,
            total_agree: request_info.agree,
            executed: request_info.executed
        });
    }

    //Member revoke request fund.
    public entry fun revokeRequestFund(
        vault: &mut VaultDAO,
        request_info: &mut RequestFundInfo,
        registry_request: &mut RegistryRequest,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        let member_address = sender(ctx);
        let request_info_id = id_address(request_info);

        assert!(table::contains(&mut vault.dao, member_address), ERR_NO_REVOKE_REQUEST_FUND);

        assert!(vector::contains(&mut registry_request.request_fund, &request_info_id), ERR_NO_FUND);

        assert!(request_info.request_creator == member_address, ERR_NO_REVOKE_REQUEST_FUND);

        let (exist, index) = vector::index_of(&mut registry_request.request_fund, &request_info_id);
        if (exist) {
            vector::remove(&mut registry_request.request_fund, index);
        };

        event::emit(RevokeRequestFundEvent {
            vault_id: id_address(vault),
            request_info_id,
            member: member_address
        });
    }


    public entry fun requestChangeTreasury(
        new_treasury: address,
        vault: &mut VaultDAO,
        registry_request: &mut RegistryRequest,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        let member_address = sender(ctx);
        let now = clock::timestamp_ms(sclock);
        assert!(table::contains(&mut vault.dao, member_address), ERR_NO_REQUEST_CHANGE_TREASURY);
        let vote = table::borrow_mut(&mut vault.dao, member_address);
        vote.vote = true;

        let request_treasury = RequestChangeTreasuryInfo {
            id: object::new(ctx),
            request_creator: member_address,
            agree: 1,
            executed: false,
            time_confirm: now + ONE_HOURS_MS,
            new_treasury_address: new_treasury,
            voted: vector::empty()
        };

        let request_treasury_id = id_address(&request_treasury);

        vector::push_back(&mut request_treasury.voted, member_address);

        vector::push_back(&mut registry_request.request_treasury, request_treasury_id);

        event::emit(RequestChangeTreasuryEvent {
            vault_id: id_address(vault),
            member: member_address,
            new_treasury,
            total_agree: request_treasury.agree,
            time_confirm: request_treasury.time_confirm
        });

        transfer::share_object(request_treasury);
    }

    public entry fun confirmRequestChangeTreasury(
        vault: &mut VaultDAO,
        request_info: &mut RequestChangeTreasuryInfo,
        registry_request: &mut RegistryRequest,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        let member_address = sender(ctx);
        let now = clock::timestamp_ms(sclock);
        let request_treasury_id = id_address(request_info);

        assert!(table::contains(&mut vault.dao, member_address), ERR_NO_CONFIRM_REQUEST);

        assert!(vector::contains(&mut registry_request.request_treasury, &request_treasury_id), ERR_NO_FUND);

        assert!(!vector::contains(&mut request_info.voted, &member_address), ERR_NO_CONFIRM_REQUEST);
        assert!(request_info.time_confirm >= now, ERR_NO_CONFIRM_REQUEST);
        let vote = table::borrow_mut(&mut vault.dao, member_address);
        vote.vote = true;

        request_info.agree = request_info.agree + 1;

        vector::push_back(&mut request_info.voted, member_address);

        event::emit(ConfirmRequestChangeTreasuryEvent {
            vault_id: id_address(vault),
            request_info_id: id_address(request_info),
            member: member_address,
            total_agree: request_info.agree
        });
    }

    public entry fun executeRequestChangeTreasury(
        registry_request: &mut RegistryRequest,
        request_info: &mut RequestChangeTreasuryInfo,
        vault: &mut VaultDAO,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        let member_address = sender(ctx);
        let now = clock::timestamp_ms(sclock);
        let request_treasury_id = id_address(request_info);

        assert!(table::contains(&mut vault.dao, member_address), ERR_NO_EXCUTE_REQUEST_CHANGE_TREASURY);

        assert!(vector::contains(&mut registry_request.request_treasury, &request_treasury_id), ERR_NO_FUND);

        assert!(now <= request_info.time_confirm, ERR_NO_EXCUTE_REQUEST_CHANGE_TREASURY);

        let vote = table::borrow_mut(&mut vault.dao, member_address);

        assert!(vote.vote == true, ERR_NO_EXCUTE_REQUEST_CHANGE_TREASURY);

        assert!(vector::contains(&mut request_info.voted, &member_address), ERR_NO_EXCUTE_REQUEST_CHANGE_TREASURY);

        assert!(request_info.agree >= vault.num_confirmations_required, ERR_NO_EXCUTE_REQUEST_CHANGE_TREASURY);

        request_info.executed = true;

        vault.treasury = request_info.new_treasury_address;

        event::emit(ExecuteRequestChangeTreasuryEvent {
            vault_id: id_address(vault),
            request_info_id: id_address(request_info),
            member: member_address,
            new_treasury: vault.treasury,
            total_agree: request_info.agree
        });
    }


    public entry fun revokeRequestChangeTreasury(
        registry_request: &mut RegistryRequest,
        vault: &mut VaultDAO,
        request_info: &mut RequestChangeTreasuryInfo,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        let member_address = sender(ctx);
        let request_treasury_id = id_address(request_info);

        assert!(table::contains(&mut vault.dao, member_address), ERR_NO_REVOKE_REQUEST_CHANGE_TREASURY);

        assert!(vector::contains(&mut registry_request.request_treasury, &request_treasury_id), ERR_NO_FUND);


        assert!(request_info.request_creator == member_address, ERR_NO_REVOKE_REQUEST_CHANGE_TREASURY);

        let (exist, index) = vector::index_of(&mut registry_request.request_treasury, &request_treasury_id);
        if (exist) {
            vector::remove(&mut registry_request.request_treasury, index);
        };

        event::emit(RevokeRequestChangeTreasuryEvent {
            vault_id: id_address(vault),
            request_info_id: request_treasury_id,
            member: member_address
        });
    }

    public entry fun requestChangeVoter(
        new_address_voter: address,
        vault: &mut VaultDAO,
        registry_request: &mut RegistryRequest,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        let member_address = sender(ctx);
        let now = clock::timestamp_ms(sclock);
        assert!(table::contains(&mut vault.dao, member_address), ERR_NO_REQUEST_CHANGE_VOTER);
        let vote = table::borrow_mut(&mut vault.dao, member_address);
        vote.vote = true;

        let request_change_voter = RequestChangeVoterInfo {
            id: object::new(ctx),
            request_creator: member_address,
            agree: 1,
            executed: false,
            time_confirm: now + ONE_HOURS_MS,
            new_address_voter,
            voted: vector::empty()
        };
        let request_change_voter_id = id_address(&request_change_voter);

        vector::push_back(&mut request_change_voter.voted, member_address);

        vector::push_back(&mut registry_request.request_change_voter, request_change_voter_id);

        event::emit(RequestChangeVoterEvent {
            vault_id: id_address(vault),
            member: member_address,
            new_address_voter,
            total_agree: request_change_voter.agree,
            time_confirm: request_change_voter.time_confirm
        });

        transfer::share_object(request_change_voter);
    }

    public entry fun confirmRequestChangeVoter(
        vault: &mut VaultDAO,
        request_info: &mut RequestChangeVoterInfo,
        registry_request: &mut RegistryRequest,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        let member_address = sender(ctx);
        let now = clock::timestamp_ms(sclock);
        let request_change_voter_id = id_address(request_info);

        assert!(table::contains(&mut vault.dao, member_address), ERR_NO_CONFIRM_REQUEST);

        assert!(vector::contains(&mut registry_request.request_change_voter, &request_change_voter_id), ERR_NO_FUND);

        assert!(!vector::contains(&mut request_info.voted, &member_address), ERR_NO_CONFIRM_REQUEST);
        assert!(request_info.time_confirm >= now, ERR_NO_CONFIRM_REQUEST);
        let vote = table::borrow_mut(&mut vault.dao, member_address);
        vote.vote = true;

        request_info.agree = request_info.agree + 1;

        vector::push_back(&mut request_info.voted, member_address);

        event::emit(ConfirmRequestChangeVoteEvent {
            vault_id: id_address(vault),
            request_info_id: request_change_voter_id,
            member: member_address,
            total_agree: request_info.agree,
        });
    }

    public entry fun executeRequestChangeVoter(
        registry_request: &mut RegistryRequest,
        request_info: &mut RequestChangeVoterInfo,
        vault: &mut VaultDAO,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        let member_address = sender(ctx);
        let now = clock::timestamp_ms(sclock);
        let request_change_voter_id = id_address(request_info);

        assert!(table::contains(&mut vault.dao, member_address), ERR_NO_EXECUTE_REQUEST_CHANGE_VOTER);

        assert!(vector::contains(&mut registry_request.request_change_voter, &request_change_voter_id), ERR_NO_FUND);

        assert!(now <= request_info.time_confirm, ERR_NO_EXECUTE_REQUEST_CHANGE_VOTER);

        let vote = table::borrow_mut(&mut vault.dao, member_address);

        assert!(vote.vote == true, ERR_NO_EXECUTE_REQUEST_CHANGE_VOTER);

        assert!(vector::contains(&mut request_info.voted, &member_address), ERR_NO_EXECUTE_REQUEST_CHANGE_VOTER);

        assert!(request_info.agree >= vault.num_confirmations_required, ERR_NO_EXECUTE_REQUEST_CHANGE_VOTER);

        request_info.executed = true;

        table::remove(&mut vault.dao, request_info.request_creator);

        vault.quorum = vault.quorum - 1;

        let vote = VoteInfo {
            vote: false
        };

        table::add(&mut vault.dao, request_info.new_address_voter, vote);

        vault.quorum = vault.quorum + 1;

        event::emit(ExecuteRequestChangeVoterEvent {
            vault_id: id_address(vault),
            request_info_id: request_change_voter_id,
            member: member_address,
            new_address_voter: request_info.new_address_voter,
            total_agree: request_info.agree
        });
    }

    public entry fun revokeRequestChangeVoter(
        registry_request: &mut RegistryRequest,
        vault: &mut VaultDAO,
        request_info: &mut RequestChangeVoterInfo,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        let member_address = sender(ctx);
        let request_change_voter_id = id_address(request_info);

        assert!(table::contains(&mut vault.dao, member_address), ERR_NO_REVOKE_REQUEST_CHANGE_VOTER);

        assert!(vector::contains(&mut registry_request.request_change_voter, &request_change_voter_id), ERR_NO_FUND);


        assert!(
            request_info.new_address_voter == member_address || request_info.request_creator == member_address,
            ERR_NO_REVOKE_REQUEST_CHANGE_VOTER
        );

        let (exist, index) = vector::index_of(&mut registry_request.request_change_voter, &request_change_voter_id);
        if (exist) {
            vector::remove(&mut registry_request.request_change_voter, index);
        };

        event::emit(RevokeRequestChangeVoterEvent {
            vault_id: id_address(vault),
            request_info_id: request_change_voter_id,
            member: member_address
        });
    }


    fun addRegistryStakePool(itemIndexes: &mut RegistryStakePool, owner: address, stakeItemId: address) {
        if (table::contains(&itemIndexes.user_items, owner)) {
            let stakeItemIds = table::borrow_mut(&mut itemIndexes.user_items, owner);
            let (exist, _index) = vector::index_of(stakeItemIds, &stakeItemId);
            if (!exist) {
                vector::push_back(stakeItemIds, stakeItemId);
            }
        } else {
            let stakeItemIds = vector::empty<address>();
            vector::push_back(&mut stakeItemIds, stakeItemId);
            table::add(&mut itemIndexes.user_items, owner, stakeItemIds);
        };
    }

    fun removeRegistryStakePool(registry: &mut RegistryStakePool, owner: address, stakeItemId: address) {
        if (table::contains(&registry.user_items, owner)) {
            let stakeItemIds = table::borrow_mut(&mut registry.user_items, owner);
            let (exist, index) = vector::index_of(stakeItemIds, &stakeItemId);
            if (exist) {
                vector::remove(stakeItemIds, index);
            };
            if (vector::length(stakeItemIds) == 0) {
                table::remove(&mut registry.user_items, owner);
            }
        }
    }

    #[test_only]
    public fun initForTesting(ctx: &mut TxContext) {
        init(STAKE {}, ctx);
    }
}