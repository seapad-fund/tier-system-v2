module seapad::stake {

    use std::vector;
    use sui::event::emit;
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

    const ONE_YEARS_MS: u64 = 31536000000;

    const TEN_DAYS_MS: u64 = 864000000;
    const SIXTY_DAYS_MS: u64 = 5184000000;
    const ONE_HUNDRED_EIGHTY_DAYS_MS: u64 = 15552000000;
    const THREE_HUNDRED_SIXTY_DAYS_MS: u64 = 31104000000;

    const VERSION: u64 = 1;

    struct STAKE has drop {}

    struct Admincap has store, key {
        id: UID,
    }

    struct StakePool<phantom S, phantom R> has key, store {
        id: UID,
        apy: u128,
        paused: bool,
        lock_period: u64,
        total_reward_claimed: u128,
        reward_coins: Coin<R>,
        stake_coins: Coin<S>,
        stakes: vector<address>
    }

    struct StakeItems has key, store {
        id: UID,
        owner: address,
        apy: u128,
        staked_amount: u128,
        reward_remaining: u128,
        lastest_updated_time: u64,
        unlock_times: u64
    }

    struct UserItemIndexes has key, store {
        id: UID,
        pools: vector<address>,
        user_items: Table<address, vector<address>>
    }

    struct CreatePoolEvent has drop, copy {
        pool_id: address,
        apy: u128,
        lock_period: u64
    }

    struct StakeEvent has drop, store, copy {
        pool_id: address,
        user_address: address,
        apy: u128,
        user_staked_amount: u128,
        user_lastest_updated_time: u64,
        unlock_times: u64,
    }

    struct UnStakeEvent has drop, store, copy {
        pool_id: address,
        user_address: address,
        user_staked_amount: u128,
        user_reward_remaining: u128,
        user_unlock_time: u64,
        stake_item_id: address
    }

    struct RestakeEvent has drop, store, copy {
        pool_id: address,
        user_address: address,
        amount: u128,
        stake_item_id: address
    }

    struct MigrateStakeEvent has drop, store, copy {
        pool_id: address,
        user_address: address,
        amount: u128
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


    fun init(_witness: STAKE, ctx: &mut TxContext) {
        let adminCap = Admincap { id: object::new(ctx) };
        transfer::transfer(adminCap, sender(ctx));

        share_object(UserItemIndexes {
            id: object::new(ctx),
            pools: vector::empty<address>(),
            user_items: table::new(ctx),
        })
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
        pool.paused = false;
    }

    public entry fun createPool<S, R>(
        _admin: &Admincap,
        apy: u128,
        lock_period: u64,
        user_item_indexes: &mut UserItemIndexes,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        assert!(apy > 0u128 && lock_period > 0, ERR_BAD_FUND_PARAMS);

        let pool = StakePool<S, R> {
            id: object::new(ctx),
            apy,
            paused: false,
            lock_period,
            total_reward_claimed: 0,
            stake_coins: coin::zero(ctx),
            reward_coins: coin::zero(ctx),
            stakes: vector::empty()
        };

        let poolId = id_address(&pool);
        vector::push_back(&mut user_item_indexes.pools, poolId);

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
        user_item_indexes: &mut UserItemIndexes,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        assert!(!pool.paused, ERR_PAUSED);

        let now = clock::timestamp_ms(sclock);
        let stake_amount = (coin::value(&coins) as u128);
        assert!(stake_amount > 0u128, ERR_AMOUNT_CANNOT_BE_ZERO);

        let user_address = sender(ctx);
        let apy_pool = pool.apy;

        let user_stake_item = StakeItems {
            id: object::new(ctx),
            owner: user_address,
            apy: apy_pool,
            staked_amount: stake_amount,
            reward_remaining: 0,
            lastest_updated_time: now,
            unlock_times: now + pool.lock_period
        };

        let stake_items_id = id_address(&user_stake_item);

        let (exist, _index) = vector::index_of(&pool.stakes, &user_address);
        if (!exist) {
            vector::push_back(&mut pool.stakes, user_address);
        };

        addUserItemIndexes(user_item_indexes, user_address, stake_items_id);

        coin::join(&mut pool.stake_coins, coins);

        event::emit(StakeEvent {
            pool_id: object::uid_to_address(&pool.id),
            user_address,
            apy: apy_pool,
            user_staked_amount: stake_amount,
            user_lastest_updated_time: now,
            unlock_times: now + pool.lock_period,
        });

        transfer::share_object(user_stake_item);
    }

    public fun unstake<S, R>(
        pool: &mut StakePool<S, R>,
        sclock: &Clock,
        stake_items_id: &mut StakeItems,
        user_item_indexes: &mut UserItemIndexes,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        assert!(!pool.paused, ERR_PAUSED);
        let now = clock::timestamp_ms(sclock);
        let user_address = sender(ctx);

        assert!(vector::contains(&pool.stakes, &user_address), ERR_NO_STAKE);
        assert!(table::contains(&user_item_indexes.user_items, user_address), ERR_NO_STAKE);
        assert!(now >= stake_items_id.unlock_times, ERR_TOO_EARLY_UNSTAKE);
        let apy_stakeItem = stake_items_id.apy;

        update_reward_remaining(apy_stakeItem, now, stake_items_id);

        pool.total_reward_claimed = pool.total_reward_claimed + stake_items_id.reward_remaining;

        stake_items_id.unlock_times = now + pool.lock_period;


        let value = (coin::value(&pool.reward_coins) as u128);
        let reward = stake_items_id.reward_remaining;
        assert!(reward > 0u128 && value >= reward, ERR_NO_FUND);

        stake_items_id.reward_remaining = 0;

        let reward = coin::split(&mut pool.reward_coins, (reward as u64), ctx);

        transfer::public_transfer(reward, user_address);

        let value = (coin::value(&pool.stake_coins) as u128);
        let amount = stake_items_id.staked_amount;
        assert!(value > 0 && value >= amount, ERR_NOT_ENOUGH_S_BALANCE);

        stake_items_id.staked_amount = 0;

        let coin = coin::split(&mut pool.stake_coins, (amount as u64), ctx);

        transfer::public_transfer(coin, user_address);


        event::emit(UnStakeEvent {
            pool_id: object::uid_to_address(&pool.id),
            user_address,
            user_staked_amount: amount,
            user_reward_remaining: stake_items_id.reward_remaining,
            user_unlock_time: stake_items_id.unlock_times,
            stake_item_id: object::uid_to_address(&stake_items_id.id)
        });
    }


    public entry fun restake<S, R>(
        pool: &mut StakePool<S, R>,
        stake_items_id: &mut StakeItems,
        coins: Coin<S>,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        assert!(!pool.paused, ERR_PAUSED);
        let user_address = sender(ctx);
        let stake_amount = (coin::value(&coins) as u128);
        assert!(stake_amount > 0u128, ERR_BAD_FUND_PARAMS);
        assert!(vector::contains(&pool.stakes, &user_address), ERR_NO_FUND);
        assert!(stake_items_id.owner == user_address, ERR_NO_FUND);

        let value = (coin::value(&pool.stake_coins) as u128);
        let amounts = stake_items_id.staked_amount;
        assert!(value > 0 && value >= amounts, ERR_NOT_ENOUGH_S_BALANCE);

        stake_items_id.staked_amount = 0;

        let coin = coin::split(&mut pool.stake_coins, (amounts as u64), ctx);

        transfer::public_transfer(coin, user_address);

        stake_items_id.staked_amount = stake_items_id.staked_amount + stake_amount ;

        coin::join(&mut pool.stake_coins, coins);


        event::emit(RestakeEvent {
            pool_id: object::uid_to_address(&pool.id),
            user_address,
            amount: stake_amount,
            stake_item_id: object::uid_to_address(&stake_items_id.id),
        });
    }


    public entry fun migrateStake<S, R>(
        _admin: &Admincap,
        pool: &mut StakePool<S, R>,
        user_item_indexes: &mut UserItemIndexes,
        user_address: address,
        coins: Coin<S>,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        assert!(!pool.paused, ERR_PAUSED);

        let now = clock::timestamp_ms(sclock);
        let stake_amount = (coin::value(&coins) as u128);
        assert!(stake_amount > 0u128, ERR_AMOUNT_CANNOT_BE_ZERO);

        let apy_pool = pool.apy;

        let user_stake_item = StakeItems {
            id: object::new(ctx),
            owner: user_address,
            apy: apy_pool,
            staked_amount: stake_amount,
            reward_remaining: 0,
            lastest_updated_time: now,
            unlock_times: now + pool.lock_period
        };

        let stake_items_id = id_address(&user_stake_item);

        let (exist, _index) = vector::index_of(&pool.stakes, &user_address);
        if (!exist) {
            vector::push_back(&mut pool.stakes, user_address);
        };

        addUserItemIndexes(user_item_indexes, user_address, stake_items_id);

        coin::join(&mut pool.stake_coins, coins);

        event::emit(MigrateStakeEvent {
            pool_id: object::uid_to_address(&pool.id),
            user_address,
            amount: stake_amount,
        });

        share_object(user_stake_item);
    }

    public entry fun claim<S, R>(
        pool: &mut StakePool<S, R>,
        stake_items_id: &mut StakeItems,
        user_item_indexes: &mut UserItemIndexes,
        sclock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        assert!(!pool.paused, ERR_PAUSED);
        let now = clock::timestamp_ms(sclock);
        let user_address = sender(ctx);
        let pool_address = object::uid_to_address(&pool.id);
        assert!(stake_items_id.unlock_times >= now, ERR_NO_FUND);
        assert!(vector::contains(&pool.stakes, &user_address), ERR_NO_FUND);
        assert!(stake_items_id.owner == user_address, ERR_NO_FUND);
        assert!(vector::contains(&user_item_indexes.pools, &pool_address), ERR_BAD_FUND_PARAMS);

        update_reward_remaining(stake_items_id.apy, now, stake_items_id);

        pool.total_reward_claimed = pool.total_reward_claimed + stake_items_id.reward_remaining;

        let value = (coin::value(&pool.reward_coins) as u128);
        let reward = stake_items_id.reward_remaining;
        assert!(reward > 0u128 && value >= reward, ERR_NO_FUND);

        stake_items_id.reward_remaining = 0;

        let reward = coin::split(&mut pool.reward_coins, (reward as u64), ctx);

        transfer::public_transfer(reward, user_address);

        event::emit(ClaimEvent {
            pool_id: object::uid_to_address(&pool.id),
            user_address,
            amount_claimed: value,
            stake_item_id: object::uid_to_address(&stake_items_id.id)
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
    public entry fun withdrawRewardCoins<S, R>(
        _admin: &Admincap,
        pool: &mut StakePool<S, R>,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        let value = (coin::value(&pool.reward_coins) as u128);
        assert!(value > 0u128, ERR_NO_FUND);
        let coin = coin::split(&mut pool.reward_coins, (value as u64), ctx);
        transfer::public_transfer(coin, sender(ctx));

        event::emit(WithdarawRewardEvent {
            pool_id: object::id_address(pool),
            total_reward: value
        });
    }


    fun update_reward_remaining(
        apy: u128,
        now: u64,
        user_stake: &mut StakeItems) {
        assert!(apy > 0u128, ERR_BAD_FUND_PARAMS);

        let time_diff = ((now - user_stake.lastest_updated_time) as u128);

        let reward_increase = ((time_diff * user_stake.staked_amount * apy) / (ONE_YEARS_MS * 10000 as u128));

        user_stake.reward_remaining = user_stake.reward_remaining + reward_increase;

        user_stake.lastest_updated_time = now;
    }


    fun addUserItemIndexes(itemIndexes: &mut UserItemIndexes, owner: address, stakeItemId: address) {
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
}