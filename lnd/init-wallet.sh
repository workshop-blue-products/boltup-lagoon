#!/bin/bash

set -e

echo "[DEBUG]"
echo "BITCOIN_NETWORK=${BITCOIN_NETWORK}"
echo "LND_ALIAS=${LND_ALIAS}"

ep /app/lnd.conf


# Adding neutrino peers based on selected network
if [ "$BITCOIN_NETWORK" == "mainnet" ]; then
    cat <<EOT >> /app/lnd.conf

[neutrino]
# Mainnet addpeers
neutrino.addpeer=btcd-mainnet.lightning.computer
neutrino.addpeer=mainnet1-btcd.zaphq.io
neutrino.addpeer=mainnet2-btcd.zaphq.io
neutrino.addpeer=mainnet3-btcd.zaphq.io
neutrino.addpeer=mainnet4-btcd.zaphq.io
neutrino.feeurl=https://nodes.lightning.computer/fees/v1/btc-fee-estimates.json
EOT

elif [ "$BITCOIN_NETWORK" == "testnet" ]; then
    cat <<EOT >> /app/lnd.conf

[neutrino]
# Testnet addpeers
neutrino.addpeer=btcd-testnet.lightning.computer
neutrino.addpeer=lnd.bitrefill.com:18333
neutrino.addpeer=faucet.lightning.community
neutrino.addpeer=testnet1-btcd.zaphq.io
neutrino.addpeer=testnet2-btcd.zaphq.io
neutrino.addpeer=testnet3-btcd.zaphq.io
neutrino.addpeer=testnet4-btcd.zaphq.io
neutrino.feeurl=https://nodes.lightning.computer/fees/v1/btctestnet-fee-estimates.json
EOT

else

    echo "Unknown BITCOIN_NETWORK variable set to ${BITCOIN_NETWORK}, failing"
    exit 1
fi

# Create rpc.cert for btcd node. If the LND_BTCD_RPCCERT env variable is empty,
# ensure we have an empty cert, as then lnd will use public cert authorities
if [ -z "$LND_BTCD_RPCCERT" ]
then
      rm -f /app/storage/rpc.cert
      touch /app/storage/rpc.cert
else
      echo -e "$LND_BTCD_RPCCERT" > /app/storage/rpc.cert
fi


if [[ ! -d /app/storage/lnd ]]; then
    mkdir -p /app/storage/lnd
fi

if [[ ! -f /app/storage/seed.txt ]]; then
    lndinit gen-seed > /app/storage/seed.txt
fi

if [[ ! -f /app/storage/walletpassword.txt ]]; then
    echo "${LND_WALLETPASSWORD}" > /app/storage/walletpassword.txt
fi

lndinit -v init-wallet \
    --secret-source=file \
    --file.seed=/app/storage/seed.txt \
    --file.wallet-password=/app/storage/walletpassword.txt \
    --init-file.output-wallet-dir=/.lnd/data/chain/bitcoin/${BITCOIN_NETWORK}

# And finally start lnd. We need to use "exec" here to make sure all signals are
# forwarded correctly.
echo ""
echo "[STARTUP] Starting lnd with flags: $@"
exec lnd "$@"