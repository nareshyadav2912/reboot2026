package org.blockchain.chaincode;

import org.hyperledger.fabric.contract.annotation.DataType;
import org.hyperledger.fabric.contract.annotation.Property;

@DataType
public class HistoryRecord {

    @Property
    private String txId;

    @Property
    private String timestamp;

    @Property
    private boolean deleted;

    @Property
    private MortgageCase mortgageCase;

    public HistoryRecord() {
    }

    public HistoryRecord(String txId,
                         String timestamp,
                         boolean deleted,
                         MortgageCase mortgageCase) {

        this.txId = txId;
        this.timestamp = timestamp;
        this.deleted = deleted;
        this.mortgageCase = mortgageCase;
    }

    public String getTxId() {
        return txId;
    }

    public String getTimestamp() {
        return timestamp;
    }

    public boolean isDeleted() {
        return deleted;
    }

    public MortgageCase getMortgageCase() {
        return mortgageCase;
    }
}