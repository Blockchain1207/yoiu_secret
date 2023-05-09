FUNCTION=$1

WALLET="admin"
WALLET_ADDRESS="secret190ljxxy9tmlptnuwtt3dsecz6gggs730k4qgac"
TIER_LABEL="my tier"
IDO_LABEL="test-ido2"
IDO_TOKEN_LABEL="my IDOToken2"
PAYMENT_TOKEN_LABEL="my payment token"

IDO_ADDRESS="secret1fqt9ldl4q95d6jl78zp0drjq57zpaavcushn6t"
IDO_TOKEN="secret14qrcvgx0z5jphyk5d2prk0axga5msu7dukppgw"
PAYMENT_TOKEN="secret18cm5s7gh7xcqnqe6xw3napgdd394nw65l0m8z4"
NFT_ADDRESS="secret1tvse5flddwsz4myc77szdu0ugxjwpmufh06s6y"

COMMON_JSON="common"
VALIDATOR_JSON="validator"
TIER_JSON="tier"
BAND_JSON="band"
DEPOSIT_JSON="deposit"
IDO_JSON="ido"

OUTPUT_DIR="output/"
[ ! -d $OUTPUT_DIR ] && mkdir $OUTPUT_DIR

# testnet
BAND_CONTRACT="secret14swdnnllsfvtnvwmtvnvcj2zu0njsl9cdkk5xp"

# mainnet
# BAND_CONTRACT="secret1ezamax2vrhjpy92fnujlpwfj2dpredaafss47k"

VALIDATOR="secretvaloper1exc4dmsswv2jfghzq5wlq6u3m4jcy2jm57dm4y"
TIER_CODE_ID="21052"
TIER_ADDRESS="secret12af07gyee94wtj6786l4vmrpx6wwmxyvxdnq6l"
TOKEN_CODE_ID="21121"
IDO_CODE_ID="21151"

ChooseValidator () {
  # Choose a validator
  RES=""
  RES=$(secretcli query staking validators)
  echo $RES > $OUTPUT_DIR$VALIDATOR_JSON
}

UploadTier() {
  echo "secretcli tx compute store ./build/tier.wasm --gas 1700000 --from $WALLET -y"
  RES=$(secretcli tx compute store ./build/tier.wasm --gas 1700000 --from $WALLET -y)
  echo $RES > $OUTPUT_DIR$TIER_JSON
}

TireContract() {
  BAND_CONTRACT_HASH=$(secretcli query compute contract-hash "$BAND_CONTRACT" | tail -c +3)
  echo $BAND_CONTRACT_HASH
  RES=$(secretcli tx compute instantiate                     \
    "$TIER_CODE_ID"                                  \
    '{
        "validator": "'"${VALIDATOR}"'",
        "deposits": ["25000000000", "7500000000", "1500000000", "250000000"],
        "band_oracle": "'"${BAND_CONTRACT}"'",
        "band_code_hash": "'"${BAND_CONTRACT_HASH}"'"
    }'                                               \
    --gas 1500000                                    \
    --from "$WALLET"                                 \
    --label "$TIER_LABEL"                            \
    --yes)
  echo $RES > $OUTPUT_DIR$BAND_JSON
}

CheckTier() {
  # It will print the smart contract address
  secretcli query compute list-contract-by-code "$TIER_CODE_ID"

  TIER_ADDRESS=$(secretcli query compute list-contract-by-code "$TIER_CODE_ID" |
      jq -r '.[-1].contract_address')
  echo $TIER_ADDRESS
}

DepositSomeSCRT() {
  RES=$(secretcli tx compute execute "$TIER_ADDRESS"    \
    '{"deposit": { "denom":"SCRT", "amount": "425"}}'    \
    --from "$WALLET"                                    \
    --gas 200000                                        \
    --amount 5000uscrt                                  \
    --yes)
  echo $RES > $OUTPUT_DIR$DEPOSIT_JSON
}

CheckMyTier() {
  RES=$(secretcli q compute query "$TIER_ADDRESS" \
    '{ "user_info": {"address":"'"$WALLET_ADDRESS"'"} }')
  echo $RES
}

WithdrawMySCRT() {
  RES=$(secretcli tx compute execute "$TIER_ADDRESS" \
    '{ "withdraw": {} }'                     \
    --from "$WALLET"                         \
    --yes)
  echo $RES > $OUTPUT_DIR$BAND_JSON
}

ClaimAfterUnbond() {
  RES=$(secretcli tx compute execute "$TIER_ADDRESS" \
    '{ "claim": {} }'                        \
    --from "$WALLET"                         \
    --yes)
  echo $RES
}

DeployIDO() {
  RES=$(secretcli tx compute store ./build/ido.wasm \
    --gas 2700000                           \
    --from "$WALLET"                        \
    --yes)
  echo $RES > $OUTPUT_DIR$IDO_JSON
}

InstantiateIDO () {
  NFT_CONTRACT_HASH=$(secretcli query compute contract-hash "${NFT_ADDRESS}" | tail -c +3)
  TIER_CONTRACT_HASH=$(secretcli query compute contract-hash "${TIER_ADDRESS}" | tail -c +3)

  #"lock_periods": [864000, 1209600, 1209600, 1209600, 1209600],
  secretcli tx compute instantiate                             \
      "$IDO_CODE_ID"                                           \
      '{
          "lock_periods": [1800, 1800, 1800, 1800, 1800],
          "nft_contract": "'"${NFT_ADDRESS}"'",
          "nft_contract_hash": "'"${NFT_CONTRACT_HASH}"'",
          "tier_contract": "'"${TIER_ADDRESS}"'",
          "tier_contract_hash": "'"${TIER_CONTRACT_HASH}"'"
      }'                                                       \
      --gas 2000000                                            \
      --from "$WALLET"                                         \
      --label "$IDO_LABEL"                                     \
      --yes | jq -r '.logs[0].events[0].attributes[-1].value'
}

CheckIDO() {
  # It will print the smart contract address
  secretcli query compute list-contract-by-code "$IDO_CODE_ID"

  IDO_ADDRESS=$(secretcli query compute list-contract-by-code "$IDO_CODE_ID" | jq -r '.[-1].contract_address')
  echo $IDO_ADDRESS
}

CreateIDO() {
  AMOUNT=1000000000000
  TOKENS_PER_TIER='["400000000000", "300000000000", "150000000000", "100000000000", "50000000000"]'
  
  IDO_TOKEN_HASH=$(secretcli query compute contract-hash "${IDO_TOKEN}" | tail -c +3)

  PAYMENT_TOKEN="secret18cm5s7gh7xcqnqe6xw3napgdd394nw65l0m8z4"
  PAYMENT_TOKEN_HASH=$(secretcli query compute contract-hash "${PAYMENT_TOKEN}" | tail -c +3)

  secretcli tx compute execute "$IDO_TOKEN"    \
      '{
          "increase_allowance": {
              "spender": "'"$IDO_ADDRESS"'",
              "amount": "'"$AMOUNT"'"
          }
      }'                                             \
      --from "$WALLET"                               \
      --yes

  # pay with native token
  PAYMENT_TOKEN_OPTION='"native"'

  # pay with custom token
  # PAYMENT_TOKEN_OPTION='{
  #     "token": {
  #         "contract": "'"${PAYMENT_TOKEN}"'",
  #         "code_hash": "'"${PAYMENT_TOKEN_HASH}"'"
  #     }
  # }'

  # shared whitelist
  WHITELIST_OPTION='{"shared": {}}'

  # empty whitelist
  # WHITELIST_OPTION='{"empty": {}}'

  START_TIME=$(date +%s)
  # END_TIME=$(date --date='2023-05-10' +%s)
  END_TIME=$(($START_TIME + 300))
  PRICE=50
  SOFT_CAP=10000000000
  echo $END_TIME


  RES=$(secretcli tx compute execute "$IDO_ADDRESS"                    \
      '{
          "start_ido": {
              "start_time": '"${START_TIME}"',
              "end_time": '"${END_TIME}"',
              "total_amount": "'"$AMOUNT"'",
              "tokens_per_tier": '"${TOKENS_PER_TIER}"',
              "price": "'"${PRICE}"'",
              "token_contract": "'"${IDO_TOKEN}"'",
              "token_contract_hash": "'"${IDO_TOKEN_HASH}"'",
              "payment": '"${PAYMENT_TOKEN_OPTION}"',
              "whitelist": '"${WHITELIST_OPTION}"',
              "soft_cap": "'"$SOFT_CAP"'"
          }
      }'                                                         \
      --from "$WALLET"                                           \
      --yes)
    echo $RES > $OUTPUT_DIR$COMMON_JSON
}

AddWhiteList() {
  IDO_ID=0

  secretcli tx compute execute "$IDO_ADDRESS" \
      '{
          "whitelist_add": {
              "addresses": ["user address"],
              "ido_id": '"${IDO_ID}"'
          }
      }'                                      \
      --from "$WALLET"                        \
      --yes
}

BuySomeToken() {
  IDO_ID=0
  AMOUNT=1000000000

  # amount * price
  MONEY=20000000
  
  secretcli tx compute execute "$PAYMENT_TOKEN" \
      '{
          "increase_allowance": {
              "spender": "'"$IDO_ADDRESS"'",
              "amount": "'"$MONEY"'"
          }
      }'                                        \
      --from "$WALLET"                          \
      --yes
  
  sleep 5
  secretcli tx compute execute "$IDO_ADDRESS" \
      '{
          "buy_tokens": {
              "amount": "'"$AMOUNT"'",
              "ido_id": '"$IDO_ID"'
          }
      }'                                      \
      --from "$WALLET"                        \
      --gas 500000                           \
      --yes
}

ReceiveToken () {
  IDO_ID=0
  secretcli tx compute execute "$IDO_ADDRESS" \
    '{
        "recv_tokens": {
            "ido_id": '"$IDO_ID"'
        }
    }'                                      \
    --from "$WALLET"                        \
    --gas 500000                           \
    --yes
}

UploadSNIP20() {
  RES=$(secretcli tx compute store ./build/contract.wasm \
    --from "$WALLET" \
    --gas 4000000 \
    -y)
  echo $RES > $OUTPUT_DIR$COMMON_JSON
}

TokenInstantiate() {
  RES=$(secretcli tx compute instantiate                     \
    "$TOKEN_CODE_ID"                                         \
    '{
        "name": "Test IDDO",
        "symbol": "TESTIDDO",
        "decimals": 6,
        "prng_seed": "",
        "initial_balances": [{"address": "'$WALLET_ADDRESS'", "amount": "1000000000000000000"}],
        "config": {
          "enable_mint": true
        }
    }'                                                       \
    --gas 1500000                                            \
    --from "$WALLET"                                         \
    --label "$IDO_TOKEN_LABEL"                               \
    --yes)
  echo $RES > $OUTPUT_DIR$COMMON_JSON
}

TokenMint() {
  RES=$(secretcli tx compute execute "$IDO_TOKEN" '{"mint": {"recipient": "'$WALLET'", "amount": "1000000000000000000" }}' --from "$WALLET" --gas 500000 --yes)
  echo $RES
}

GetHash() {
  IDO_TOKEN_HASH=$(secretcli query compute contract-hash "${IDO_ADDRESS}" | tail -c +3)
  echo $IDO_TOKEN_HASH
}

GetTime() {
  START_TIME=$(date +%s)
  # END_TIME=$(date --date='2023-05-10' +%s)
  END_TIME=$(($START_TIME + 3600))
  echo $END_TIME
}

if [[ $FUNCTION == "" ]]; then
  ChooseValidator
else
  $FUNCTION
fi