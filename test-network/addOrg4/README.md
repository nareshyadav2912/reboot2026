# Adding Org4 to the Test Network

You can use the `addOrg4.sh` script to add another organization to the Fabric test network. The `addOrg4.sh` script generates the Org4 crypto material, creates an Org4 organization definition, and adds Org4 to a channel on the test network.

You first need to run `./network.sh up createChannel` in the `test-network` directory before you can run the `addOrg4.sh` script.

```
./network.sh up createChannel
cd addOrg4
./addOrg4.sh up
```

If you used `network.sh` to create a channel other than the default `mychannel`, you need pass that name to the `addOrg4.sh` script.
```
./network.sh up createChannel -c channel1
cd addOrg4
./addOrg4.sh up -c channel1
```

You can also re-run the `addOrg4.sh` script to add Org4 to additional channels.
```
cd ..
./network.sh createChannel -c channel2
cd addOrg4
./addOrg4.sh up -c channel2
```

## Using CouchDB

If you want to use CouchDB as the state database for Org4, pass the `-s couchdb` flag to the script. CouchDB will be deployed on port 9984.

```
./addOrg4.sh up -s couchdb
```

## Using Fabric CA

You can also use the `addOrg4.sh` script to deploy Org4 with a Fabric CA. The `-ca` flag will deploy a Fabric CA for Org4 and use the CA to generate the Org4 crypto material.

```
./addOrg4.sh up -ca
```

The Org4 CA will be deployed on port 11055.

## Explanation

The `addOrg4.sh` script orchestrates the following steps:

1. **Generate Org4 crypto material**: Using either cryptogen or Fabric CA
2. **Generate Org4 organization definition**: Using configtxgen
3. **Bring up Org4 peer container**: Using docker-compose
4. **Update channel configuration**: Add Org4 to the channel
5. **Join Org4 peer to the channel**: Using peer channel join

The Org4 peer uses port 11052 for peer communication.
