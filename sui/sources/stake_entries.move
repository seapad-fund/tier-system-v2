module seapad::stake_entries {
    use sui::clock::Clock;
    use sui::coin::Coin;
    use sui::tx_context::TxContext;
    use seapad::stake;
    use seapad::version::Version;
    use seapad::stake::{Admincap, StakePool, RegistryStakePool, StakeItem, VaultDAO, RequestFundInfo,
        RequestChangeTreasuryInfo, RegistryRequest, RequestChangeVoterInfo, Providers, UserStakePoolInfo, RequestId
    };

    public entry fun change_admin(adminCap: Admincap,
                                  to: address,
                                  version: &mut Version) {
        stake::change_admin(adminCap, to, version);
    }

    public entry fun pause<S, R>(_admin: &Admincap, pool: &mut StakePool<S, R>, version: &mut Version) {
        stake::pause(_admin, pool, version);
    }

    public entry fun unPause<S, R>(_admin: &Admincap, pool: &mut StakePool<S, R>, version: &mut Version) {
        stake::unPause(_admin, pool, version);
    }

    public entry fun stopAll<S, R>(_admin: &Admincap, pool: &mut StakePool<S, R>, version: &mut Version) {
        stake::stopAll(_admin, pool, version);
    }

    public entry fun unStopAll<S, R>(_admin: &Admincap, pool: &mut StakePool<S, R>, version: &mut Version) {
        stake::unStopAll(_admin, pool, version);
    }


    public entry fun addProvider(
        _admin: &Admincap,
        provider: &mut Providers,
        provider_new_address: address,
        version: &mut Version
    ) {
        stake::addProvider(_admin, provider, provider_new_address, version);
    }

    public entry fun removeProvider(
        _admin: &Admincap,
        provider: &mut Providers,
        provider_address: address,
        version: &mut Version
    ) {
        stake::removeProvider(_admin, provider, provider_address, version);
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
        stake::createPool<S, R>(_admin, apy, lock_period, user_item_indexes, rTypeCoin, sTypeCoin, version, ctx);
    }

    public fun stake<S, R>(
        pool: &mut StakePool<S, R>,
        coins: Coin<S>,
        sclock: &Clock,
        user_item_indexes: &mut RegistryStakePool,
        user_info_pool: &mut UserStakePoolInfo,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        stake::stake(pool, coins, sclock, user_item_indexes, user_info_pool, version, ctx);
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
        stake::upgradeStakeItem(
            pool_old,
            pool_new,
            stake_items_id,
            user_item_indexes,
            sclock,
            user_info_pool,
            version,
            ctx
        );
    }

    public fun unstake<S, R>(
        pool: &mut StakePool<S, R>,
        sclock: &Clock,
        stake_items_id: &mut StakeItem,
        user_item_indexes: &mut RegistryStakePool,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        stake::unstake(pool, sclock, stake_items_id, user_item_indexes, version, ctx);
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
        stake::reStakeRewards(pool, stake_items_id, user_item_indexes, user_info_pool, version, sclock, ctx);
    }

    public entry fun restake<S, R>(
        pool: &mut StakePool<S, R>,
        stake_items_id: &mut StakeItem,
        user_item_indexes: &mut RegistryStakePool,
        version: &mut Version,
        sclock: &Clock,
        ctx: &mut TxContext
    ) {
        stake::restake(pool, stake_items_id, user_item_indexes, version, sclock, ctx);
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
        stake::migrateStake(
            provider,
            pool,
            user_item_indexes,
            user_info_pool,
            request_id,
            _reqId,
            user_address,
            coins,
            sclock,
            version,
            ctx
        );
    }

    public entry fun claim<S, R>(
        pool: &mut StakePool<S, R>,
        stake_items_id: &mut StakeItem,
        user_item_indexes: &mut RegistryStakePool,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        stake::claim(pool, stake_items_id, user_item_indexes, sclock, version, ctx);
    }

    public entry fun updateLockPeriod<S, R>(
        _admin: &Admincap,
        pool: &mut StakePool<S, R>,
        lock_period: u64,
        version: &mut Version,
    ) {
        stake::updateLockPeriod(_admin, pool, lock_period, version);
    }

    public entry fun updateMinStake<S, R>(
        _admin: &Admincap,
        pool: &mut StakePool<S, R>,
        value: u128,
        version: &mut Version,
    ) {
        stake::updateMinStake(_admin, pool, value, version);
    }

    public entry fun depositRewardCoins<S, R>(
        _admin: &Admincap,
        pool: &mut StakePool<S, R>,
        version: &mut Version,
        coins: Coin<R>
    ) {
        stake::depositRewardCoins(_admin, pool, version, coins);
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
        stake::stopEmergency(
            _admin,
            pool,
            stake_items_id,
            user_item_indexes,
            user_info_pool,
            owner,
            paused,
            version,
            sclock,
            ctx
        );
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
        stake::updateApyStakeItem(_admin, apy, owner, stake_items_id, user_item_indexes, sclock, version);
    }

    public entry fun updateApyPool<S, R>(
        _admin: &Admincap,
        pool: &mut StakePool<S, R>,
        apy: u128,
        version: &mut Version,
    ) {
        stake::updateApyPool(_admin, pool, apy, version);
    }


    public entry fun requestFund<S, R>(
        pool: &mut StakePool<S, R>,
        vault: &mut VaultDAO,
        registry_pool: &mut RegistryStakePool,
        registry_request: &mut RegistryRequest,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        stake::requestFund(pool, vault, registry_pool, registry_request, sclock, version, ctx);
    }

    public entry fun confirmRequestFund(
        vault: &mut VaultDAO,
        request_info: &mut RequestFundInfo,
        registry_request: &mut RegistryRequest,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        stake::confirmRequestFund(vault, request_info, registry_request, sclock, version, ctx);
    }

    public entry fun executeRequestFund<S, R>(
        pool: &mut StakePool<S, R>,
        request_info: &mut RequestFundInfo,
        registry_request: &mut RegistryRequest,
        vault: &mut VaultDAO,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        stake::executeRequestFund(pool, request_info, registry_request, vault, sclock, version, ctx);
    }


    public entry fun revokeRequestFund(
        vault: &mut VaultDAO,
        request_info: &mut RequestFundInfo,
        registry_request: &mut RegistryRequest,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        stake::revokeRequestFund(vault, request_info, registry_request, version, ctx);
    }

    public entry fun requestChangeTreasury(
        new_treasury: address,
        vault: &mut VaultDAO,
        registry_request: &mut RegistryRequest,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        stake::requestChangeTreasury(new_treasury, vault, registry_request, sclock, version, ctx);
    }

    public entry fun confirmRequestChangeTreasury(
        vault: &mut VaultDAO,
        request_info: &mut RequestChangeTreasuryInfo,
        registry_request: &mut RegistryRequest,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        stake::confirmRequestChangeTreasury(vault, request_info, registry_request, sclock, version, ctx);
    }

    public entry fun executeRequestChangeTreasury(
        registry_request: &mut RegistryRequest,
        request_info: &mut RequestChangeTreasuryInfo,
        vault: &mut VaultDAO,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        stake::executeRequestChangeTreasury(registry_request, request_info, vault, sclock, version, ctx);
    }

    public entry fun revokeRequestChangeTreasury(
        registry_request: &mut RegistryRequest,
        vault: &mut VaultDAO,
        request_info: &mut RequestChangeTreasuryInfo,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        stake::revokeRequestChangeTreasury(registry_request, vault, request_info, version, ctx);
    }

    public entry fun requestChangeVoter(
        new_address_voter: address,
        vault: &mut VaultDAO,
        registry_request: &mut RegistryRequest,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        stake::requestChangeVoter(new_address_voter, vault, registry_request, sclock, version, ctx);
    }

    public entry fun confirmRequestChangeVote(
        vault: &mut VaultDAO,
        request_info: &mut RequestChangeVoterInfo,
        registry_request: &mut RegistryRequest,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        stake::confirmRequestChangeVoter(vault, request_info, registry_request, sclock, version, ctx);
    }

    public entry fun executeRequestChangeVoter(
        registry_request: &mut RegistryRequest,
        request_info: &mut RequestChangeVoterInfo,
        vault: &mut VaultDAO,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        stake::executeRequestChangeVoter(registry_request, request_info, vault, sclock, version, ctx);
    }

    public entry fun revokeRequestChangeVoter(
        registry_request: &mut RegistryRequest,
        vault: &mut VaultDAO,
        request_info: &mut RequestChangeVoterInfo,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        stake::revokeRequestChangeVoter(registry_request, vault, request_info, version, ctx);
    }
}