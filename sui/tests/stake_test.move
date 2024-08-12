#[test_only]
module seapad::stake_test {


    use sui::clock;
    use sui::coin;
    use sui::clock::Clock;
    use seapad::stake;
    use seapad::version::{Version, initForTest};
    use seapad::stake::{StakePool, Admincap, RegistryStakePool, StakeItem, VaultDAO, RequestFundInfo, RegistryRequest,
        RequestChangeTreasuryInfo, RequestChangeVoterInfo, UserStakePoolInfo, Providers
    };
    use sui::test_scenario;
    use sui::test_scenario::{Scenario, return_shared, ctx, next_tx, take_from_sender, return_to_sender};

    const ADMIN: address = @0xC0FFEE;
    const SEED_FUND: address = @0xC0FFFF;
    const USER_ERR: address = @alice;

    const REWARD_VALUE: u128 = 10000000000;
    const STAKE_VALUE: u128 = 100000000000;
    const RESTAKE_VALUE: u128 = 50000000000;
    const APY: u128 = 2000;
    const APY_UPDATE: u128 = 3000;
    const LOCK_PERIOD: u64 = 86400000;
    const LOCK_PERIOD_UPDATE: u64 = 86400002;
    const TIME_UNSTAKE: u64 = 86400001;
    const TIME_CLAIM: u64 = 86400001;
    const TIME_CONFITMED: u64 = 3500000;
    const TIME_NO_CONFIRM: u64 = 3600001;
    const REWARD_UNSTAKED: u64 = 54794522;
    const REWARD_UNSTAKED_AFTER_UPDATE_APY: u64 = 82191782;
    const REWARD_CLAIMED: u64 = 54794522;
    const R_TYPE_COIN: vector<u8> = b"Coin R";
    const S_TYPE_COIN: vector<u8> = b"Coin S";
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_AMOUNT_CANNOT_BE_ZERO)]
    // fun test_value_stake() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     next_tx(scenario, SEED_FUND);
    //     //User stake
    //     stake(SEED_FUND, &mut pool, 0, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_UNSTAKE)]
    // fun test_user_not_unstake() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool and deposit reward coins
    //     let pool = create_pool(scenario);
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     next_tx(scenario, SEED_FUND);
    //     stake(SEED_FUND, &mut pool, STAKE_VALUE, &clock, scenario);
    //
    //     next_tx(scenario, SEED_FUND);
    //     clock::increment_for_testing(&mut clock, TIME_UNSTAKE);
    //     unstake(USER_ERR, &mut pool, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    #[test]
    fun test_stake() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        let ctx = ctx(scenario);
        let clock = clock::create_for_testing(ctx);
        init_env(scenario);
        next_tx(scenario, ADMIN);

        //Create pool
        let pool = create_pool(scenario);

        next_tx(scenario, SEED_FUND);
        //User stake
        stake(SEED_FUND, &mut pool, STAKE_VALUE, &clock, scenario);

        // next_tx(scenario, SEED_FUND);
        // clock::increment_for_testing(&mut clock, 10000);
        // stake(SEED_FUND, &mut pool, STAKE_VALUE, &clock, scenario);

        // test_scenario::next_tx(scenario, SEED_FUND);
        //     {
        //         let coin_staked = take_from_sender<Coin<STAKE_COIN>>(scenario);
        //         assert!(coin::value(&coin_staked) == (STAKE_VALUE  as u64), 0);
        //         return_to_sender(scenario, coin_staked);
        //     };

        clock::destroy_for_testing(clock);
        return_shared(pool);
        test_scenario::end(scenario_val);
    }

    // #[test]
    // fun test_unstake() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool and deposit reward coins
    //     let pool = create_pool(scenario);
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     next_tx(scenario, SEED_FUND);
    //     stake(SEED_FUND, &mut pool, STAKE_VALUE, &clock, scenario);
    //
    //     next_tx(scenario, SEED_FUND);
    //     clock::increment_for_testing(&mut clock, TIME_UNSTAKE);
    //     //User unstake
    //     unstake(SEED_FUND, &mut pool, &clock, scenario);
    //
    //     test_scenario::next_tx(scenario, SEED_FUND);
    //     {
    //         let coin_stake = take_from_sender<Coin<STAKE_COIN>>(scenario);
    //         assert!(coin::value(&coin_stake) == (STAKE_VALUE as u64), 0);
    //         return_to_sender(scenario, coin_stake);
    //     };
    //
    //     test_scenario::next_tx(scenario, SEED_FUND);
    //     {
    //         let coin_reward = take_from_sender<Coin<REWARD_COIN>>(scenario);
    //         assert!(coin::value(&coin_reward) < REWARD_UNSTAKED, 0);
    //         return_to_sender(scenario, coin_reward);
    //     };
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    //
    // #[test]
    // fun test_pause() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //pause pool
    //     pause(&mut pool, scenario);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // fun test_unPause() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //pause pool
    //     pause(&mut pool, scenario);
    //
    //     //unPause pool
    //     unPause(&mut pool, scenario);
    //
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // fun test_restake() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     next_tx(scenario, SEED_FUND);
    //     //User stake
    //     stake(SEED_FUND, &mut pool, STAKE_VALUE, &clock, scenario);
    //
    //
    //     //User restake
    //     restake(SEED_FUND, &mut pool, RESTAKE_VALUE, scenario);
    //
    //
    //     test_scenario::next_tx(scenario, SEED_FUND);
    //     {
    //         let coin_stake = take_from_sender<Coin<STAKE_COIN>>(scenario);
    //         assert!(coin::value(&coin_stake) == (STAKE_VALUE as u64), 0);
    //         return_to_sender(scenario, coin_stake);
    //     };
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_BAD_FUND_PARAMS)]
    // fun test_user_not_restake() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     next_tx(scenario, SEED_FUND);
    //     //User stake
    //     stake(SEED_FUND, &mut pool, STAKE_VALUE, &clock, scenario);
    //
    //     next_tx(scenario, SEED_FUND);
    //     clock::increment_for_testing(&mut clock, TIME_UNSTAKE);
    //     //User unstake
    //     unstake(SEED_FUND, &mut pool, &clock, scenario);
    //
    //     //User restake
    //     restake(USER_ERR, &mut pool, RESTAKE_VALUE, scenario);
    //
    //     test_scenario::next_tx(scenario, SEED_FUND);
    //     {
    //         let coin_reward = take_from_sender<Coin<REWARD_COIN>>(scenario);
    //         assert!(coin::value(&coin_reward) < REWARD_UNSTAKED, 0);
    //         return_to_sender(scenario, coin_reward);
    //     };
    //
    //     test_scenario::next_tx(scenario, SEED_FUND);
    //     {
    //         let coin_stake = take_from_sender<Coin<STAKE_COIN>>(scenario);
    //         assert!(coin::value(&coin_stake) == (STAKE_VALUE as u64), 0);
    //         return_to_sender(scenario, coin_stake);
    //     };
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // fun test_migrate_stake() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins.
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     next_tx(scenario, ADMIN);
    //     //Admin migrate stake for user.
    //     migrateStake(&mut pool, SEED_FUND, STAKE_VALUE, &clock, scenario);
    //
    //
    //     next_tx(scenario, SEED_FUND);
    //     clock::increment_for_testing(&mut clock, TIME_UNSTAKE);
    //
    //     //User unstake
    //     unstake(SEED_FUND, &mut pool, &clock, scenario);
    //
    //     test_scenario::next_tx(scenario, SEED_FUND);
    //     {
    //         let coin_reward = take_from_sender<Coin<REWARD_COIN>>(scenario);
    //         assert!(coin::value(&coin_reward) < REWARD_UNSTAKED, 0);
    //         return_to_sender(scenario, coin_reward);
    //     };
    //
    //     test_scenario::next_tx(scenario, SEED_FUND);
    //     {
    //         let coin_stake = take_from_sender<Coin<STAKE_COIN>>(scenario);
    //         assert!(coin::value(&coin_stake) == (STAKE_VALUE as u64), 0);
    //         return_to_sender(scenario, coin_stake);
    //     };
    //
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // fun test_claim() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     next_tx(scenario, SEED_FUND);
    //     //User stake
    //     stake(SEED_FUND, &mut pool, STAKE_VALUE, &clock, scenario);
    //
    //
    //     next_tx(scenario, SEED_FUND);
    //     clock::increment_for_testing(&mut clock, TIME_CLAIM);
    //     //User claim after time claim
    //     claim(SEED_FUND, &mut pool, &clock, scenario);
    //
    //     test_scenario::next_tx(scenario, SEED_FUND);
    //     {
    //         let coin_reward = take_from_sender<Coin<REWARD_COIN>>(scenario);
    //         assert!(coin::value(&coin_reward) < REWARD_CLAIMED, 0);
    //         return_to_sender(scenario, coin_reward);
    //     };
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_FUND)]
    // fun test_user_not_claim() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     next_tx(scenario, SEED_FUND);
    //     //User stake
    //     stake(SEED_FUND, &mut pool, STAKE_VALUE, &clock, scenario);
    //
    //     next_tx(scenario, SEED_FUND);
    //     clock::increment_for_testing(&mut clock, TIME_UNSTAKE);
    //     //user unstake after time unstake
    //     unstake(SEED_FUND, &mut pool, &clock, scenario);
    //
    //     next_tx(scenario, SEED_FUND);
    //     //User claim
    //     claim(SEED_FUND, &mut pool, &clock, scenario);
    //
    //     test_scenario::next_tx(scenario, SEED_FUND);
    //     {
    //         let coin_reward = take_from_sender<Coin<REWARD_COIN>>(scenario);
    //         assert!(coin::value(&coin_reward) < REWARD_CLAIMED, 0);
    //         return_to_sender(scenario, coin_reward);
    //     };
    //
    //     test_scenario::next_tx(scenario, SEED_FUND);
    //     {
    //         let coin_stake = take_from_sender<Coin<STAKE_COIN>>(scenario);
    //         assert!(coin::value(&coin_stake) == (STAKE_VALUE as u64), 0);
    //         return_to_sender(scenario, coin_stake);
    //     };
    //
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // fun test_stop_emergency() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     next_tx(scenario, SEED_FUND);
    //     //User stake
    //     stake(SEED_FUND, &mut pool, STAKE_VALUE, &clock, scenario);
    //
    //     next_tx(scenario, ADMIN);
    //     stopEmergency(&mut pool, SEED_FUND, true, scenario);
    //
    //     test_scenario::next_tx(scenario, SEED_FUND);
    //     {
    //         let coin_stake = take_from_sender<Coin<STAKE_COIN>>(scenario);
    //         assert!(coin::value(&coin_stake) == (STAKE_VALUE as u64), 0);
    //         return_to_sender(scenario, coin_stake);
    //     };
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // fun test_update_apy() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     next_tx(scenario, SEED_FUND);
    //     //User stake
    //     stake(SEED_FUND, &mut pool, STAKE_VALUE, &clock, scenario);
    //
    //     next_tx(scenario, ADMIN);
    //     //Admin update Apy
    //     updateApy(&mut pool, APY_UPDATE, SEED_FUND, &clock, scenario);
    //
    //     next_tx(scenario, SEED_FUND);
    //     clock::increment_for_testing(&mut clock, TIME_UNSTAKE);
    //     //user unstake after time unstake
    //     unstake(SEED_FUND, &mut pool, &clock, scenario);
    //
    //     test_scenario::next_tx(scenario, SEED_FUND);
    //     {
    //         let coin_reward = take_from_sender<Coin<REWARD_COIN>>(scenario);
    //         assert!(coin::value(&coin_reward) < REWARD_UNSTAKED_AFTER_UPDATE_APY, 0);
    //         return_to_sender(scenario, coin_reward);
    //     };
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // fun test_update_lock_period() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     next_tx(scenario, SEED_FUND);
    //     //User stake
    //     stake(SEED_FUND, &mut pool, STAKE_VALUE, &clock, scenario);
    //
    //     next_tx(scenario, ADMIN);
    //     //Admin update lock period
    //     updateLockPeriod(&mut pool, LOCK_PERIOD_UPDATE, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_TOO_EARLY_UNSTAKE)]
    // fun test_user_not_unstake_afer_update_lock_period() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     next_tx(scenario, SEED_FUND);
    //     //User stake
    //     stake(SEED_FUND, &mut pool, STAKE_VALUE, &clock, scenario);
    //
    //     next_tx(scenario, ADMIN);
    //     //Admin update lock period
    //     updateLockPeriod(&mut pool, LOCK_PERIOD_UPDATE, scenario);
    //
    //     next_tx(scenario, USER_ERR);
    //     //new user stake with period new.
    //     stake(USER_ERR, &mut pool, STAKE_VALUE, &clock, scenario);
    //
    //     next_tx(scenario, USER_ERR);
    //     clock::increment_for_testing(&mut clock, TIME_UNSTAKE);
    //     //user unstake after time unstake
    //     unstake(USER_ERR, &mut pool, &clock, scenario);
    //
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // fun test_deposit_reward_coins() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    //
    // #[test]
    // fun test_request_fund() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     //member request withdraw fund
    //     next_tx(scenario, @alice);
    //     requestFund(@alice, &mut pool, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_REQUEST_FUND)]
    // fun test_member_no_request_fund() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     //member request withdraw fund --> ERR because in not table dao
    //     next_tx(scenario, SEED_FUND);
    //     requestFund(SEED_FUND, &mut pool, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // fun test_confirm_request_fund() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     //member request withdraw fund
    //     next_tx(scenario, @alice);
    //     requestFund(@alice, &mut pool, &clock, scenario);
    //
    //     //member comfirm request fund
    //
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     confirmRequestFund(@bob, &clock, scenario);
    //
    //     // next_tx(scenario, @emergency);
    //     // confirmRequestFund(@emergency, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_CONFIRM_REQUEST)]
    // fun test_no_confirm_request_fund() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     //member request withdraw fund
    //     next_tx(scenario, @alice);
    //     requestFund(@alice, &mut pool, &clock, scenario);
    //
    //     //member comfirm request fund -- > ERR because invalid time
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_NO_CONFIRM);
    //     confirmRequestFund(@bob, &clock, scenario);
    //
    //     // next_tx(scenario, @emergency);
    //     // confirmRequestFund(@emergency, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_CONFIRM_REQUEST)]
    // fun test_no_confirm_request_fund_v2() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     //member request withdraw fund
    //     next_tx(scenario, @alice);
    //     requestFund(@alice, &mut pool, &clock, scenario);
    //
    //     //member comfirm request fund -- > ERR because voted.
    //     next_tx(scenario, @alice);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     confirmRequestFund(@alice, &clock, scenario);
    //
    //     // next_tx(scenario, @emergency);
    //     // confirmRequestFund(@emergency, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // fun test_execute_request_fund() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //
    //     //member request withdraw fund
    //     next_tx(scenario, @alice);
    //     requestFund(@alice, &mut pool, &clock, scenario);
    //
    //     //member comfirm request fund
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     confirmRequestFund(@bob, &clock, scenario);
    //
    //     next_tx(scenario, @emergency);
    //     confirmRequestFund(@emergency, &clock, scenario);
    //
    //     // member execute request fund
    //     next_tx(scenario, @emergency);
    //     executeRequestFund(@emergency, &clock, &mut pool, scenario);
    //
    //
    //     test_scenario::next_tx(scenario, @treasury);
    //     {
    //         let coin_reward = take_from_sender<Coin<REWARD_COIN>>(scenario);
    //         assert!(coin::value(&coin_reward) == (REWARD_VALUE as u64), 0);
    //         return_to_sender(scenario, coin_reward);
    //     };
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_EXCUTE_REQUEST_FUND)]
    // fun test_err_execute_request_fund() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //
    //     //member request withdraw fund
    //     next_tx(scenario, @alice);
    //     requestFund(@alice, &mut pool, &clock, scenario);
    //
    //     //member comfirm request fund
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     confirmRequestFund(@bob, &clock, scenario);
    //
    //     next_tx(scenario, @emergency);
    //     confirmRequestFund(@emergency, &clock, scenario);
    //
    //     // member execute request fund --> ERR because in not vault
    //     next_tx(scenario, SEED_FUND);
    //     executeRequestFund(SEED_FUND, &clock, &mut pool, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_EXCUTE_REQUEST_FUND)]
    // fun test_err_execute_request_fund_v2() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //
    //     //member request withdraw fund
    //     next_tx(scenario, @alice);
    //     requestFund(@alice, &mut pool, &clock, scenario);
    //
    //     //member comfirm request fund
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     confirmRequestFund(@bob, &clock, scenario);
    //
    //     // member execute request fund --> Err because no vote
    //     next_tx(scenario, @emergency);
    //     executeRequestFund(@emergency, &clock, &mut pool, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_EXCUTE_REQUEST_FUND)]
    // fun test_err_execute_request_fund_v3() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //
    //     //member request withdraw fund
    //     next_tx(scenario, @alice);
    //     requestFund(@alice, &mut pool, &clock, scenario);
    //
    //     // member execute request fund --> Err because aggree < num_confirmations_required
    //     next_tx(scenario, @alice);
    //     executeRequestFund(@alice, &clock, &mut pool, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // fun test_revoke_request_fund() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     //member request withdraw fund
    //     next_tx(scenario, @alice);
    //     requestFund(@alice, &mut pool, &clock, scenario);
    //
    //
    //     next_tx(scenario, @alice);
    //     //Member revoke request fund.
    //     revokeRequestFund(@alice, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_REVOKE_REQUEST_FUND)]
    // fun test_err_revoke_request_fund() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     //member request withdraw fund
    //     next_tx(scenario, @alice);
    //     requestFund(@alice, &mut pool, &clock, scenario);
    //
    //
    //     next_tx(scenario, SEED_FUND);
    //     //Member revoke request fund -- Err because member is not vault
    //     revokeRequestFund(SEED_FUND, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_REVOKE_REQUEST_FUND)]
    // fun test_err_revoke_request_fund_v2() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     //member request withdraw fund
    //     next_tx(scenario, @alice);
    //     requestFund(@alice, &mut pool, &clock, scenario);
    //
    //
    //     next_tx(scenario, @bob);
    //     //Member revoke request fund --> Err because member is not create request.
    //     revokeRequestFund(@bob, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_FUND)]
    // fun test_err_revoke_request_fund_with_confirm_request() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //     next_tx(scenario, ADMIN);
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     //member request withdraw fund
    //     next_tx(scenario, @alice);
    //     requestFund(@alice, &mut pool, &clock, scenario);
    //
    //
    //     next_tx(scenario, @alice);
    //     //Member revoke request fund
    //     revokeRequestFund(@alice, scenario);
    //
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     //Member confirm request fund --> Err because request has been deleted!!!
    //     confirmRequestFund(@bob, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // fun test_request_change_treasury() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, @alice);
    //
    //     //Member create request change treasury new .
    //     requestChangeTreasury(@alice, @treasury_new, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_REQUEST_CHANGE_TREASURY)]
    // fun test_member_no_request_change_treasury() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, @jame);
    //
    //     //Member create request change treasury new --> ERR because member not in vault.
    //     requestChangeTreasury(@jame, @treasury_new, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // fun test_confirm_request_change_treasury() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, @alice);
    //
    //     //Member create request change treasury new .
    //     requestChangeTreasury(@alice, @treasury_new, &clock, scenario);
    //
    //     //member comfirm request fund
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     // Member in vault confirm request change treasury.
    //     confirmRequestChangeTreasury(@bob, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_CONFIRM_REQUEST)]
    // fun test_err_no_confirm_request_change_treasury() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, @alice);
    //
    //     //Member create request change treasury new .
    //     requestChangeTreasury(@alice, @treasury_new, &clock, scenario);
    //
    //     //member comfirm request fund
    //     next_tx(scenario, @alice);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     // Member in vault confirm request change treasury --> Err because member voted
    //     confirmRequestChangeTreasury(@alice, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_CONFIRM_REQUEST)]
    // fun test_err_no_confirm_request_change_treasury_v2() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, @alice);
    //
    //     //Member create request change treasury new .
    //     requestChangeTreasury(@alice, @treasury_new, &clock, scenario);
    //
    //     //member comfirm request fund
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_NO_CONFIRM);
    //     // Member in vault confirm request change treasury --> Err because Confirmation time has passed
    //     confirmRequestChangeTreasury(@bob, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // fun test_execute_request_change_treasury() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, @alice);
    //
    //     //Member create request change treasury new .
    //     requestChangeTreasury(@alice, @treasury_new, &clock, scenario);
    //
    //     //member comfirm request fund
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     // Member in vault confirm request change treasury
    //     confirmRequestChangeTreasury(@bob, &clock, scenario);
    //
    //     next_tx(scenario, @emergency);
    //     confirmRequestChangeTreasury(@emergency, &clock, scenario);
    //
    //     //Member voted call execute request change treasury.
    //     executeRequestChangeTreasury(@emergency, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_EXCUTE_REQUEST_CHANGE_TREASURY)]
    // fun test_err_execute_request_change_treasury() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, @alice);
    //
    //     //Member create request change treasury new .
    //     requestChangeTreasury(@alice, @treasury_new, &clock, scenario);
    //
    //     //member comfirm request fund
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     // Member in vault confirm request change treasury
    //     confirmRequestChangeTreasury(@bob, &clock, scenario);
    //
    //     next_tx(scenario, @emergency);
    //     confirmRequestChangeTreasury(@emergency, &clock, scenario);
    //
    //     next_tx(scenario, @jame);
    //     //Member voted call execute request change treasury.--> ERR because member is not vault.
    //     executeRequestChangeTreasury(@jame, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_EXCUTE_REQUEST_CHANGE_TREASURY)]
    // fun test_err_execute_request_change_treasury_v2() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, @alice);
    //
    //     //Member create request change treasury new .
    //     requestChangeTreasury(@alice, @treasury_new, &clock, scenario);
    //
    //     //member comfirm request change treasury new
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     // Member in vault confirm request change treasury
    //     confirmRequestChangeTreasury(@bob, &clock, scenario);
    //
    //     next_tx(scenario, @emergency);
    //     confirmRequestChangeTreasury(@emergency, &clock, scenario);
    //
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_NO_CONFIRM);
    //     //Member voted call execute request change treasury.--> ERR because Err because execute request time has passed
    //     executeRequestChangeTreasury(@bob, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_EXCUTE_REQUEST_CHANGE_TREASURY)]
    // fun test_err_execute_request_change_treasury_v3() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, @alice);
    //
    //     //Member create request change treasury new .
    //     requestChangeTreasury(@alice, @treasury_new, &clock, scenario);
    //
    //     //member comfirm request change treasury new
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     // Member in vault confirm request change treasury
    //     confirmRequestChangeTreasury(@bob, &clock, scenario);
    //
    //     next_tx(scenario, @emergency);
    //     //Member voted call execute request change treasury.--> ERR because Err because member is not vote
    //     executeRequestChangeTreasury(@emergency, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_EXCUTE_REQUEST_CHANGE_TREASURY)]
    // fun test_err_execute_request_change_treasury_v4() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, @alice);
    //
    //     //Member create request change treasury new .
    //     requestChangeTreasury(@alice, @treasury_new, &clock, scenario);
    //
    //
    //     next_tx(scenario, @alice);
    //     //Member voted call execute request change treasury.--> ERR because Err because agree < num_confirmations_required
    //     executeRequestChangeTreasury(@alice, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // fun change_treasury_and_execute_request_fun() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //     next_tx(scenario, @alice);
    //
    //     //Member create request change treasury new .
    //     requestChangeTreasury(@alice, @treasury_new, &clock, scenario);
    //
    //     //member comfirm request change treasury
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     // Member in vault confirm request change treasury
    //     confirmRequestChangeTreasury(@bob, &clock, scenario);
    //
    //     next_tx(scenario, @emergency);
    //     confirmRequestChangeTreasury(@emergency, &clock, scenario);
    //
    //     //Member voted call execute request change treasury.
    //     executeRequestChangeTreasury(@emergency, &clock, scenario);
    //
    //     next_tx(scenario, ADMIN);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED - TIME_CONFITMED);
    //     //Create pool
    //     let pool = create_pool(scenario);
    //
    //     //Deposit reward coins
    //     depositRewardCoins(&mut pool, REWARD_VALUE, scenario);
    //
    //     //member request withdraw fund
    //     next_tx(scenario, @alice);
    //     requestFund(@alice, &mut pool, &clock, scenario);
    //
    //     //member comfirm request fund
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     confirmRequestFund(@bob, &clock, scenario);
    //
    //     next_tx(scenario, @emergency);
    //     confirmRequestFund(@emergency, &clock, scenario);
    //
    //     // member execute request fund
    //     next_tx(scenario, @emergency);
    //     executeRequestFund(@emergency, &clock, &mut pool, scenario);
    //
    //
    //     test_scenario::next_tx(scenario, @treasury_new);
    //     {
    //         let coin_reward = take_from_sender<Coin<REWARD_COIN>>(scenario);
    //         assert!(coin::value(&coin_reward) == (REWARD_VALUE as u64), 0);
    //         return_to_sender(scenario, coin_reward);
    //     };
    //
    //     clock::destroy_for_testing(clock);
    //     return_shared(pool);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // fun test_revoke_request_change_treasury() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //
    //     init_env(scenario);
    //
    //     next_tx(scenario, @emergency);
    //     //Member create request change treasury new .
    //     requestChangeTreasury(@emergency, @treasury_new, &clock, scenario);
    //
    //     next_tx(scenario, @emergency);
    //     //Member revoke request change treasury new.
    //     revokeRequestChangeTreasury(@emergency, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_REVOKE_REQUEST_CHANGE_TREASURY)]
    // fun test_err_no_revoke_request_change_treasury() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //
    //     next_tx(scenario, @emergency);
    //     //Member create request change treasury new .
    //     requestChangeTreasury(@emergency, @treasury_new, &clock, scenario);
    //
    //     next_tx(scenario, @alice);
    //     //Member revoke request change treasury--> Err because member is not create request!!!
    //     revokeRequestChangeTreasury(@alice, scenario);
    //
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_FUND)]
    // fun test_revoke_request_change_treasury_with_confirm_change_treasury() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //
    //     next_tx(scenario, @emergency);
    //     //Member create request change treasury new .
    //     requestChangeTreasury(@emergency, @treasury_new, &clock, scenario);
    //
    //     next_tx(scenario, @emergency);
    //     //Member revoke request change treasury
    //     revokeRequestChangeTreasury(@emergency, scenario);
    //
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     //Member confirm request change treasury --> Err because request has been deleted!!!
    //     confirmRequestChangeTreasury(@bob, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // fun test_request_change_voter() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //
    //     next_tx(scenario, @alice);
    //     // Member create request change voter.
    //     requestChangeVoter(@alice, @jame, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_REQUEST_CHANGE_VOTER)]
    // fun test_mem_err_request_change_voter() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //
    //     next_tx(scenario, @jame);
    //     // Member create request change voter --> Err because member is not in vault
    //     requestChangeVoter(@jame, @mary, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // fun test_confirm_request_change_voter() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //
    //     next_tx(scenario, @alice);
    //     // Member create request change voter.
    //     requestChangeVoter(@alice, @alice_new, &clock, scenario);
    //
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     //Member confirm request change voter.
    //     confirmRequestChangeVoter(@bob, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_CONFIRM_REQUEST)]
    // fun test_err_confirm_request_change_voter() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //
    //     next_tx(scenario, @alice);
    //     // Member create request change voter.
    //     requestChangeVoter(@alice, @alice_new, &clock, scenario);
    //
    //     next_tx(scenario, @jame);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     //Member confirm request change voter --> Err because member is not in vault.
    //     confirmRequestChangeVoter(@jame, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_CONFIRM_REQUEST)]
    // fun test_err_confirm_request_change_voter_v2() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //
    //     next_tx(scenario, @alice);
    //     // Member create request change voter.
    //     requestChangeVoter(@alice, @alice_new, &clock, scenario);
    //
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_NO_CONFIRM);
    //     //Member confirm request change voter --> Err because time has passed.
    //     confirmRequestChangeVoter(@bob, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_CONFIRM_REQUEST)]
    // fun test_err_confirm_request_change_voter_v3() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //
    //     next_tx(scenario, @alice);
    //     // Member create request change voter.
    //     requestChangeVoter(@alice, @alice_new, &clock, scenario);
    //
    //     next_tx(scenario, @alice);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     //Member confirm request change voter --> Err because member voted
    //     confirmRequestChangeVoter(@alice, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    //
    // #[test]
    // fun test_execute_request_change_voter() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //
    //     next_tx(scenario, @alice);
    //     // Member create request change voter.
    //     requestChangeVoter(@alice, @alice_new, &clock, scenario);
    //
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     //Member confirm request change voter.
    //     confirmRequestChangeVoter(@bob, &clock, scenario);
    //
    //     next_tx(scenario, @alice);
    //     //Member execute request change voter
    //     executeRequestChangeVoter(@alice, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_EXECUTE_REQUEST_CHANGE_VOTER)]
    // fun test_err_execute_request_change_voter() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //
    //     next_tx(scenario, @alice);
    //     // Member create request change voter.
    //     requestChangeVoter(@alice, @alice_new, &clock, scenario);
    //
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     //Member confirm request change voter.
    //     confirmRequestChangeVoter(@bob, &clock, scenario);
    //
    //     next_tx(scenario, @jame);
    //     //Member execute request change voter --> Err because member is not in vault.
    //     executeRequestChangeVoter(@jame, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_EXECUTE_REQUEST_CHANGE_VOTER)]
    // fun test_err_execute_request_change_voter_v2() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //
    //     next_tx(scenario, @alice);
    //     // Member create request change voter.
    //     requestChangeVoter(@alice, @alice_new, &clock, scenario);
    //
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     //Member confirm request change voter.
    //     confirmRequestChangeVoter(@bob, &clock, scenario);
    //
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_NO_CONFIRM);
    //     //Member execute request change voter --> Err because time has passed.
    //     executeRequestChangeVoter(@bob, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    //
    // #[test]
    // fun test_revoke_request_change_voter() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //
    //     next_tx(scenario, @alice);
    //     // Member create request change voter.
    //     requestChangeVoter(@alice, @alice_new, &clock, scenario);
    //
    //     next_tx(scenario, @alice);
    //     //Member revoke request change voter.
    //     revokeRequestChangeVoter(@alice, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // fun test_revoke_request_change_voter_v2() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //
    //     next_tx(scenario, @alice);
    //     // Member create request change voter.
    //     requestChangeVoter(@alice, @alice_new, &clock, scenario);
    //
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     //Member confirm request change voter.
    //     confirmRequestChangeVoter(@bob, &clock, scenario);
    //
    //     next_tx(scenario, @alice);
    //     //Member execute request change voter
    //     executeRequestChangeVoter(@alice, &clock, scenario);
    //
    //     next_tx(scenario, @alice_new);
    //     //Member revoke request change voter with account new
    //     revokeRequestChangeVoter(@alice_new, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_REVOKE_REQUEST_CHANGE_VOTER)]
    // fun test_err_revoke_request_change_voter() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //
    //     next_tx(scenario, @alice);
    //     // Member create request change voter.
    //     requestChangeVoter(@alice, @alice_new, &clock, scenario);
    //
    //     next_tx(scenario, @jame);
    //     //Member revoke request change voter--> Err becasuse member is not in vault.
    //     revokeRequestChangeVoter(@jame, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_REVOKE_REQUEST_CHANGE_VOTER)]
    // fun test_err_revoke_request_change_voter_v2() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //
    //     next_tx(scenario, @alice);
    //     // Member create request change voter.
    //     requestChangeVoter(@alice, @alice_new, &clock, scenario);
    //
    //     next_tx(scenario, @bob);
    //     //Member revoke request change voter--> Err becasuse member is not create request.
    //     revokeRequestChangeVoter(@bob, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }
    //
    // #[test]
    // #[expected_failure(abort_code = stake::ERR_NO_FUND)]
    // fun test_revoke_change_voter_with_confirm_change_voter() {
    //     let scenario_val = scenario();
    //     let scenario = &mut scenario_val;
    //     let ctx = ctx(scenario);
    //     let clock = clock::create_for_testing(ctx);
    //     init_env(scenario);
    //
    //     next_tx(scenario, @alice);
    //     // Member create request change voter.
    //     requestChangeVoter(@alice, @alice_new, &clock, scenario);
    //
    //     next_tx(scenario, @alice);
    //     //Member revoke request change voter.
    //     revokeRequestChangeVoter(@alice, scenario);
    //
    //     next_tx(scenario, @bob);
    //     clock::increment_for_testing(&mut clock, TIME_CONFITMED);
    //     //Member confirm request change voter.
    //     confirmRequestChangeVoter(@bob, &clock, scenario);
    //
    //     clock::destroy_for_testing(clock);
    //     test_scenario::end(scenario_val);
    // }


    fun create_pool(scenario: &mut Scenario): StakePool<STAKE_COIN, REWARD_COIN> {
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin = test_scenario::take_from_sender<Admincap>(scenario);
            let user_item_indexes = test_scenario::take_shared<RegistryStakePool>(scenario);
            let version = test_scenario::take_shared<Version>(scenario);
            let ctx = test_scenario::ctx(scenario);
            stake::createPool<STAKE_COIN, REWARD_COIN>(
                &admin,
                APY,
                LOCK_PERIOD,
                &mut user_item_indexes,
                R_TYPE_COIN,
                S_TYPE_COIN,
                &mut version,
                ctx
            );
            test_scenario::return_to_sender(scenario, admin);
            test_scenario::return_shared(user_item_indexes);
            test_scenario::return_shared(version);
        };
        test_scenario::next_tx(scenario, ADMIN);
        test_scenario::take_shared<StakePool<STAKE_COIN, REWARD_COIN>>(scenario)
    }

    fun pause(
        pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin = take_from_sender<Admincap>(scenario);
        let version = test_scenario::take_shared<Version>(scenario);

        stake::pause(&admin, pool, &mut version);

        return_to_sender(scenario, admin);
        return_shared(version);
    }

    fun unPause(
        pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin = take_from_sender<Admincap>(scenario);
        let version = test_scenario::take_shared<Version>(scenario);

        stake::unPause(&admin, pool, &mut version);

        return_to_sender(scenario, admin);
        return_shared(version);
    }


    fun stake(
        staker: address,
        pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
        stake_value: u128,
        clock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, staker);
        let version = test_scenario::take_shared<Version>(scenario);
        let user_item_indexes = test_scenario::take_shared<RegistryStakePool>(scenario);
        let user_info_pool = test_scenario::take_shared<UserStakePoolInfo>(scenario);
        let ctx = test_scenario::ctx(scenario);
        let stake_coin = coin::mint_for_testing<STAKE_COIN>((stake_value as u64), ctx);
        stake::stake(pool, stake_coin, clock, &mut user_item_indexes,&mut user_info_pool ,&mut version, ctx);
        return_shared(version);
        return_shared(user_item_indexes);
        return_shared(user_info_pool)
    }

    fun unstake(
        unstaker: address,
        pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
        clock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, unstaker);
        let version = test_scenario::take_shared<Version>(scenario);
        let user_item_indexes = test_scenario::take_shared<RegistryStakePool>(scenario);
        let stake_items_id = test_scenario::take_shared<StakeItem>(scenario);
        let user_info_pool = test_scenario::take_shared<UserStakePoolInfo>(scenario);
        let ctx = test_scenario::ctx(scenario);

        stake::unstake(pool, clock, &mut stake_items_id, &mut user_item_indexes, &mut user_info_pool ,&mut version, ctx);

        return_shared(version);
        return_shared(user_item_indexes);
        return_shared(stake_items_id);
        return_shared(user_info_pool);
    }

    fun restake(
        restaker: address,
        pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
        clock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, restaker);
        let version = test_scenario::take_shared<Version>(scenario);
        let user_item_indexes = test_scenario::take_shared<RegistryStakePool>(scenario);
        let stake_items_id = test_scenario::take_shared<StakeItem>(scenario);
        let user_info_pool = test_scenario::take_shared<UserStakePoolInfo>(scenario);
        let ctx = test_scenario::ctx(scenario);


        stake::reStakeRewards(pool, &mut stake_items_id, &mut user_item_indexes,&mut user_info_pool ,&mut version, clock, ctx);

        return_shared(version);
        return_shared(user_item_indexes);
        return_shared(stake_items_id);
        return_shared(user_info_pool);
    }

    // fun migrateStake(
    //     pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
    //     user_address: address,
    //     stake_value: u128,
    //     clock: &Clock,
    //     scenario: &mut Scenario) {
    //     test_scenario::next_tx(scenario, ADMIN);
    //     let provider = take_from_sender<Providers>(scenario);
    //     let version = test_scenario::take_shared<Version>(scenario);
    //     let user_item_indexes = test_scenario::take_shared<RegistryStakePool>(scenario);
    //     let user_info_pool = test_scenario::take_shared<UserStakePoolInfo>(scenario);
    //     let ctx = test_scenario::ctx(scenario);
    //     let stake_coin = coin::mint_for_testing<STAKE_COIN>((stake_value as u64), ctx);
    //
    //     stake::migrateStake(&mut provider, pool, &mut user_item_indexes, &mut user_info_pool, user_address, stake_coin, clock, &mut version, ctx);
    //
    //     return_to_sender(scenario, provider);
    //     return_shared(version);
    //     return_shared(user_item_indexes);
    //     return_shared(user_info_pool);
    // }

    fun claim(
        claimer: address,
        pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
        sclock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, claimer);
        let version = test_scenario::take_shared<Version>(scenario);
        let user_item_indexes = test_scenario::take_shared<RegistryStakePool>(scenario);
        let stake_items_id = test_scenario::take_shared<StakeItem>(scenario);
        let ctx = test_scenario::ctx(scenario);

        stake::claim(pool, &mut stake_items_id, &mut user_item_indexes, sclock, &mut version, ctx);

        return_shared(version);
        return_shared(user_item_indexes);
        return_shared(stake_items_id);
    }


    fun stopEmergency(
        pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
        owner: address,
        paused: bool,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin = take_from_sender<Admincap>(scenario);
        let version = test_scenario::take_shared<Version>(scenario);
        let user_item_indexes = test_scenario::take_shared<RegistryStakePool>(scenario);
        let stake_items_id = test_scenario::take_shared<StakeItem>(scenario);
        let user_info_pool = test_scenario::take_shared<UserStakePoolInfo>(scenario);
        let ctx = test_scenario::ctx(scenario);

        stake::stopEmergency(
            &admin,
            pool,
            &mut stake_items_id,
            &mut user_item_indexes,
            &mut user_info_pool,
            owner,
            paused,
            &mut version,
            ctx
        );

        return_to_sender(scenario, admin);
        return_shared(version);
        return_shared(stake_items_id);
        return_shared(user_item_indexes);
        return_shared(user_info_pool);
    }

    fun updateApy(
        apy: u128,
        owner: address,
        sclock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin = take_from_sender<Admincap>(scenario);
        let version = test_scenario::take_shared<Version>(scenario);
        let user_item_indexes = test_scenario::take_shared<RegistryStakePool>(scenario);
        let stake_items_id = test_scenario::take_shared<StakeItem>(scenario);

        stake::updateApyStakeItem(&admin, apy, owner, &mut stake_items_id, &mut user_item_indexes, sclock, &mut version);

        return_to_sender(scenario, admin);
        return_shared(version);
        return_shared(stake_items_id);
        return_shared(user_item_indexes);
    }

    fun updateLockPeriod(
        pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
        lock_period: u64,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin = take_from_sender<Admincap>(scenario);
        let version = test_scenario::take_shared<Version>(scenario);

        stake::updateLockPeriod(&admin, pool, lock_period, &mut version);

        return_to_sender(scenario, admin);
        return_shared(version);
    }

    fun depositRewardCoins(
        pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
        reward_value: u128,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin = take_from_sender<Admincap>(scenario);
        let version = test_scenario::take_shared<Version>(scenario);
        let ctx = test_scenario::ctx(scenario);
        let reward_coin = coin::mint_for_testing<REWARD_COIN>((reward_value as u64), ctx);

        stake::depositRewardCoins(&admin, pool, &mut version, reward_coin);

        return_to_sender(scenario, admin);
        return_shared(version);
    }

    fun requestFund(
        member: address,
        pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
        sclock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, member);
        let version = test_scenario::take_shared<Version>(scenario);
        let vault = test_scenario::take_shared<VaultDAO>(scenario);
        let registry_pool = test_scenario::take_shared<RegistryStakePool>(scenario);
        let registry_request = test_scenario::take_shared<RegistryRequest>(scenario);
        let ctx = test_scenario::ctx(scenario);

        stake::requestFund(
            pool,
            &mut vault,
            &mut registry_pool,
            &mut registry_request,
            sclock,
            &mut version,
            ctx
        );

        return_shared(version);
        return_shared(vault);
        return_shared(registry_pool);
        return_shared(registry_request);
    }

    fun confirmRequestFund(
        member: address,
        sclock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, member);
        let version = test_scenario::take_shared<Version>(scenario);
        let vault = test_scenario::take_shared<VaultDAO>(scenario);
        let request_info = test_scenario::take_shared<RequestFundInfo>(scenario);
        let registry_request = test_scenario::take_shared<RegistryRequest>(scenario);
        let ctx = test_scenario::ctx(scenario);

        stake::confirmRequestFund(&mut vault, &mut request_info, &mut registry_request, sclock, &mut version, ctx);

        return_shared(version);
        return_shared(vault);
        return_shared(request_info);
        return_shared(registry_request);
    }

    fun executeRequestFund(
        member: address,
        sclock: &Clock,
        pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, member);
        let version = test_scenario::take_shared<Version>(scenario);
        let vault = test_scenario::take_shared<VaultDAO>(scenario);
        let request_info = test_scenario::take_shared<RequestFundInfo>(scenario);
        let registry_request = test_scenario::take_shared<RegistryRequest>(scenario);
        let ctx = test_scenario::ctx(scenario);

        stake::executeRequestFund(
            pool,
            &mut request_info,
            &mut registry_request,
            &mut vault,
            sclock,
            &mut version,
            ctx
        );

        return_shared(version);
        return_shared(vault);
        return_shared(request_info);
        return_shared(registry_request);
    }

    fun revokeRequestFund(
        member: address,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, member);
        let version = test_scenario::take_shared<Version>(scenario);
        let vault = test_scenario::take_shared<VaultDAO>(scenario);
        let request_info = test_scenario::take_shared<RequestFundInfo>(scenario);
        let registry_request = test_scenario::take_shared<RegistryRequest>(scenario);
        let ctx = test_scenario::ctx(scenario);

        stake::revokeRequestFund(&mut vault, &mut request_info, &mut registry_request, &mut version, ctx);

        return_shared(version);
        return_shared(vault);
        return_shared(request_info);
        return_shared(registry_request);
    }

    fun requestChangeTreasury(
        member: address,
        new_treasury: address,
        sclock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, member);
        let version = test_scenario::take_shared<Version>(scenario);
        let vault = test_scenario::take_shared<VaultDAO>(scenario);
        let registry_request = test_scenario::take_shared<RegistryRequest>(scenario);
        let ctx = test_scenario::ctx(scenario);

        stake::requestChangeTreasury(new_treasury, &mut vault, &mut registry_request, sclock, &mut version, ctx);

        return_shared(version);
        return_shared(vault);
        return_shared(registry_request);
    }

    fun confirmRequestChangeTreasury(
        member: address,
        sclock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, member);
        let version = test_scenario::take_shared<Version>(scenario);
        let vault = test_scenario::take_shared<VaultDAO>(scenario);
        let request_info = test_scenario::take_shared<RequestChangeTreasuryInfo>(scenario);
        let registry_request = test_scenario::take_shared<RegistryRequest>(scenario);
        let ctx = test_scenario::ctx(scenario);

        stake::confirmRequestChangeTreasury(
            &mut vault,
            &mut request_info,
            &mut registry_request,
            sclock,
            &mut version,
            ctx
        );

        return_shared(version);
        return_shared(vault);
        return_shared(request_info);
        return_shared(registry_request);
    }

    fun executeRequestChangeTreasury(
        member: address,
        sclock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, member);
        let version = test_scenario::take_shared<Version>(scenario);
        let vault = test_scenario::take_shared<VaultDAO>(scenario);
        let request_info = test_scenario::take_shared<RequestChangeTreasuryInfo>(scenario);
        let registry_request = test_scenario::take_shared<RegistryRequest>(scenario);
        let ctx = test_scenario::ctx(scenario);

        stake::executeRequestChangeTreasury(
            &mut registry_request,
            &mut request_info,
            &mut vault,
            sclock,
            &mut version,
            ctx
        );

        return_shared(version);
        return_shared(vault);
        return_shared(request_info);
        return_shared(registry_request);
    }

    fun revokeRequestChangeTreasury(
        member: address,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, member);
        let version = test_scenario::take_shared<Version>(scenario);
        let vault = test_scenario::take_shared<VaultDAO>(scenario);
        let request_info = test_scenario::take_shared<RequestChangeTreasuryInfo>(scenario);
        let registry_request = test_scenario::take_shared<RegistryRequest>(scenario);
        let ctx = test_scenario::ctx(scenario);

        stake::revokeRequestChangeTreasury(&mut registry_request, &mut vault, &mut request_info, &mut version, ctx);

        return_shared(version);
        return_shared(vault);
        return_shared(request_info);
        return_shared(registry_request);
    }

    fun requestChangeVoter(
        member: address,
        new_address_voter: address,
        sclock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, member);
        let version = test_scenario::take_shared<Version>(scenario);
        let vault = test_scenario::take_shared<VaultDAO>(scenario);
        let registry_request = test_scenario::take_shared<RegistryRequest>(scenario);
        let ctx = test_scenario::ctx(scenario);

        stake:: requestChangeVoter(new_address_voter, &mut vault, &mut registry_request, sclock, &mut version, ctx);

        return_shared(version);
        return_shared(vault);
        return_shared(registry_request);
    }

    fun confirmRequestChangeVoter(
        member: address,
        sclock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, member);
        let version = test_scenario::take_shared<Version>(scenario);
        let vault = test_scenario::take_shared<VaultDAO>(scenario);
        let request_info = test_scenario::take_shared<RequestChangeVoterInfo>(scenario);
        let registry_request = test_scenario::take_shared<RegistryRequest>(scenario);
        let ctx = test_scenario::ctx(scenario);

        stake::confirmRequestChangeVoter(
            &mut vault,
            &mut request_info,
            &mut registry_request,
            sclock,
            &mut version,
            ctx
        );

        return_shared(version);
        return_shared(vault);
        return_shared(request_info);
        return_shared(registry_request);
    }

    fun executeRequestChangeVoter(
        member: address,
        sclock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, member);
        let version = test_scenario::take_shared<Version>(scenario);
        let vault = test_scenario::take_shared<VaultDAO>(scenario);
        let request_info = test_scenario::take_shared<RequestChangeVoterInfo>(scenario);
        let registry_request = test_scenario::take_shared<RegistryRequest>(scenario);
        let ctx = test_scenario::ctx(scenario);

        stake::executeRequestChangeVoter(
            &mut registry_request,
            &mut request_info,
            &mut vault,
            sclock,
            &mut version,
            ctx
        );

        return_shared(version);
        return_shared(vault);
        return_shared(request_info);
        return_shared(registry_request);
    }


    fun revokeRequestChangeVoter(
        member: address,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, member);
        let version = test_scenario::take_shared<Version>(scenario);
        let vault = test_scenario::take_shared<VaultDAO>(scenario);
        let request_info = test_scenario::take_shared<RequestChangeVoterInfo>(scenario);
        let registry_request = test_scenario::take_shared<RegistryRequest>(scenario);
        let ctx = test_scenario::ctx(scenario);

        stake::revokeRequestChangeVoter(&mut registry_request, &mut vault, &mut request_info, &mut version, ctx);

        return_shared(version);
        return_shared(vault);
        return_shared(request_info);
        return_shared(registry_request);
    }

    fun init_env(scenario: &mut Scenario) {
        let ctx = test_scenario::ctx(scenario);
        clock::share_for_testing(clock::create_for_testing(ctx));
        initForTest(ctx);
        stake::initForTesting(ctx);
    }

    struct REWARD_COIN has drop {}

    struct STAKE_COIN has drop {}

    fun scenario(): Scenario { test_scenario::begin(@0xC0FFEE) }
}