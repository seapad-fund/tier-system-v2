#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000 --skip-fetch-latest-git-deps --skip-dependency-verification
#sui client split-coin --coin-id 0xcf4a4a14463cc758d4083ed82202a984a7d85146865b1b252614cd4ec3284005 --gas-budget 200000000 --amounts 1000000000000000


export PACKAGE=0x5138b6700099acba113e589807fbebce7d7502214b0ce2669b273a1cd7cea35d
export UPGRADE_CAP=0xceda99911c7b558c4d0bfa4949a4c7a2cb41e50e9efcad20a33db3c47fb3f2a2
export ADMIN_CAP_STAKE=0x8c3e180f5db705384dbdfbb0fe3674af6dc4d5bf575a881b47a0d3cbe8b56e0a
export VERSION=0xc8991384d68c7d81c5e843cee9c02cba1e058fd4aa1ed12a6fccedae32733d7e
export ADMIN_CAP_VERSION=0x172f2858950cf8309088db0e152731bfbef77e9b5acc6a3d1967aa35235048b8
export REGISTRY_STAKE_POOL=0x82f614ab92420c23f58f58d299e599cf10b511ed38a8d2a61604178ad8bcab80
export REGISTRY_REQUEST=0x8f788e7400116092db11698d0847f10516f33b9c1e7a7ae7f238b84d855611f2
export VAULT_DAO=0xfde10c5872d7c5a4a8600cacbf81b2824c4441dbf174e39a631123ad390e6832
export PROVIDERS=0x1fb399dd476bbce0df5001625ab9ef025f8e57135fb937d535a68faccf851705
export USER_STAKE_POOL_INFO=0x05b5de425b579f3e5ee1b7ea25c3c0e16cc4a0a1ad722d14563e089a29783beb
export REQUEST_ID=0xadb7f396ee07d17ca0357267c0a0c068f1f3a7c8ded3be7a0812045702a589be
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

export SPT_TYPE=0x2b1584a5ddf5351ec7742e51bd7ac0ca4dee9f31cd1e568c506503e1a5b7a29f::spt::SPT
export APY_POOL_1_DAY=1000
export APY_POOL_3_DAY=2000
export APY_POOL_5_DAY=3000
export APY_POOL_10_DAY=5000
export LOCK_PERIOD_POOL_1_DAY=300000
export LOCK_PERIOD_POOL_3_DAY=360000
export LOCK_PERIOD_POOL_5_DAY=420000
export LOCK_PERIOD_POOL_10_DAY=480000


export R_TYPE_COIN="SPT"
export S_TYPE_COIN="SPT"

export POOL_1_DAY_TEST=0xcc17c9975d2d98500531ba5caed385f2787e48bd50a6c758c8da71f791c7aaaf
export POOL_3_DAY_TEST=0x80af5dfdcb463b4219f108b7826f0bed1f75c499375870325cb59f968aa2e021
export POOL_5_DAY_TEST=0x185f21cbce3ccece06787c70b251fb77c7945e04d9fe005fc089f0f78a228d51
export POOL_10_DAY_TEST=0xdea7da7d860f69299d5ee35056502dbc44e98232049b0754f0e6095ed780abfb

export COIN_POOL_1=0x44ce78ef374d5aaf01955b5f45b598f687370dc6cf3c1bf4955cb631403bdb4f
export COIN_POOL_3=0xcc20372bc33a4ffc8d8b46a6fcf3cfc6451e8e6b95f580d64d260fb6bd4e1bc7
export COIN_POOL_5=0xeed17c27e3f62e476f02f5b07806201a59e5bf914a7084360ed6b205cb6cb505
export COIN_POOL_10=0xc31953678ff7bf0bffdbffaceac198bf5da70567435eff4ffcafbdcf47ec39c8


#Transfer admin
#sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "change_admin" --args  $ADMIN_CAP_STAKE $NEW_ADMIN $VERSION

#Create Pool
#sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "createPool" --type-args $SPT_TYPE $SPT_TYPE --args $ADMIN_CAP_STAKE $APY_POOL_1_DAY $LOCK_PERIOD_POOL_1_DAY $REGISTRY_STAKE_POOL $R_TYPE_COIN $S_TYPE_COIN  $VERSION
#sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "createPool" --type-args $SPT_TYPE $SPT_TYPE --args $ADMIN_CAP_STAKE $APY_POOL_3_DAY $LOCK_PERIOD_POOL_3_DAY $REGISTRY_STAKE_POOL $R_TYPE_COIN $S_TYPE_COIN  $VERSION
#sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "createPool" --type-args $SPT_TYPE $SPT_TYPE --args $ADMIN_CAP_STAKE $APY_POOL_5_DAY $LOCK_PERIOD_POOL_5_DAY $REGISTRY_STAKE_POOL $R_TYPE_COIN $S_TYPE_COIN  $VERSION
#sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "createPool" --type-args $SPT_TYPE $SPT_TYPE --args $ADMIN_CAP_STAKE $APY_POOL_10_DAY $LOCK_PERIOD_POOL_10_DAY $REGISTRY_STAKE_POOL $R_TYPE_COIN $S_TYPE_COIN  $VERSION

#Deposit Pool
#sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "depositRewardCoins" --type-args $SPT_TYPE $SPT_TYPE --args $ADMIN_CAP_STAKE $POOL_1_DAY_TEST $VERSION $COIN_POOL_1
#sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "depositRewardCoins" --type-args $SPT_TYPE $SPT_TYPE --args $ADMIN_CAP_STAKE $POOL_3_DAY_TEST $VERSION $COIN_POOL_3
#sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "depositRewardCoins" --type-args $SPT_TYPE $SPT_TYPE --args $ADMIN_CAP_STAKE $POOL_5_DAY_TEST $VERSION $COIN_POOL_5
#sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "depositRewardCoins" --type-args $SPT_TYPE $SPT_TYPE --args $ADMIN_CAP_STAKE $POOL_10_DAY_TEST $VERSION $COIN_POOL_10



