package org.blockchain.chaincode;

import org.hyperledger.fabric.contract.annotation.DataType;
import org.hyperledger.fabric.contract.annotation.Property;

@DataType()
public class MortgageCase {

    @Property
    private String caseId;

    @Property
    private String transactionId;

    @Property
    private String propertyReference;

    @Property
    private String buyerName;

    @Property
    private String sellerName;

    @Property
    private String brokerName;

    @Property
    private String lenderName;

    @Property
    private String conveyancerName;

    @Property
    private String estateAgentName;

    @Property
    private String statusCode;

    @Property
    private String statusLabel;

    @Property
    private String updatedByRole;

    @Property
    private String updatedByOrg;

    @Property
    private String updatedByUser;

    @Property
    private String timestamp;

    @Property
    private String confidence;

    @Property
    private String evidenceHash;

    @Property
    private String visibilityLevel;

    @Property
    private boolean blocker;

    @Property
    private String blockerReason;

    @Property
    private String nextExpectedStatus;

    @Property
    private String updatedBy;

    @Property
    private String nextExpectedEvent;

    // Required by Genson
    public MortgageCase() {
    }

    public MortgageCase(String caseId,
            String transactionId,
            String propertyReference,
            String buyerName,
            String sellerName,
            String brokerName,
            String lenderName,
            String conveyancerName,
            String estateAgentName,
            String statusCode,
            String statusLabel,
            String updatedByRole,
            String updatedByOrg,
            String updatedByUser,
            String timestamp,
            String confidence,
            String evidenceHash,
            String visibilityLevel,
            boolean blocker,
            String blockerReason,
            String nextExpectedStatus,
            String updatedBy,
            String nextExpectedEvent) {

        this.caseId = caseId;
        this.transactionId = transactionId;
        this.propertyReference = propertyReference;
        this.buyerName = buyerName;
        this.sellerName = sellerName;
        this.brokerName = brokerName;
        this.lenderName = lenderName;
        this.conveyancerName = conveyancerName;
        this.estateAgentName = estateAgentName;
        this.statusCode = statusCode;
        this.statusLabel = statusLabel;
        this.updatedByRole = updatedByRole;
        this.updatedByOrg = updatedByOrg;
        this.updatedByUser = updatedByUser;
        this.timestamp = timestamp;
        this.confidence = confidence;
        this.evidenceHash = evidenceHash;
        this.visibilityLevel = visibilityLevel;
        this.blocker = blocker;
        this.blockerReason = blockerReason;
        this.nextExpectedStatus = nextExpectedStatus;
        this.updatedBy = updatedBy;
        this.nextExpectedEvent = nextExpectedEvent;
    }

    public String getCaseId() {
        return caseId;
    }

    public void setCaseId(String caseId) {
        this.caseId = caseId;
    }

    public String getTransactionId() {
        return transactionId;
    }

    public void setTransactionId(String transactionId) {
        this.transactionId = transactionId;
    }

    public String getPropertyReference() {
        return propertyReference;
    }

    public void setPropertyReference(String propertyReference) {
        this.propertyReference = propertyReference;
    }

    public String getBuyerName() {
        return buyerName;
    }

    public void setBuyerName(String buyerName) {
        this.buyerName = buyerName;
    }

    public String getSellerName() {
        return sellerName;
    }

    public void setSellerName(String sellerName) {
        this.sellerName = sellerName;
    }

    public String getBrokerName() {
        return brokerName;
    }

    public void setBrokerName(String brokerName) {
        this.brokerName = brokerName;
    }

    public String getLenderName() {
        return lenderName;
    }

    public void setLenderName(String lenderName) {
        this.lenderName = lenderName;
    }

    public String getConveyancerName() {
        return conveyancerName;
    }

    public void setConveyancerName(String conveyancerName) {
        this.conveyancerName = conveyancerName;
    }

    public String getEstateAgentName() {
        return estateAgentName;
    }

    public void setEstateAgentName(String estateAgentName) {
        this.estateAgentName = estateAgentName;
    }

    public String getStatusCode() {
        return statusCode;
    }

    public void setStatusCode(String statusCode) {
        this.statusCode = statusCode;
    }

    public String getStatusLabel() {
        return statusLabel;
    }

    public void setStatusLabel(String statusLabel) {
        this.statusLabel = statusLabel;
    }

    public String getUpdatedByRole() {
        return updatedByRole;
    }

    public void setUpdatedByRole(String updatedByRole) {
        this.updatedByRole = updatedByRole;
    }

    public String getUpdatedByOrg() {
        return updatedByOrg;
    }

    public void setUpdatedByOrg(String updatedByOrg) {
        this.updatedByOrg = updatedByOrg;
    }

    public String getUpdatedByUser() {
        return updatedByUser;
    }

    public void setUpdatedByUser(String updatedByUser) {
        this.updatedByUser = updatedByUser;
    }

    public String getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(String timestamp) {
        this.timestamp = timestamp;
    }

    public String getConfidence() {
        return confidence;
    }

    public void setConfidence(String confidence) {
        this.confidence = confidence;
    }

    public String getEvidenceHash() {
        return evidenceHash;
    }

    public void setEvidenceHash(String evidenceHash) {
        this.evidenceHash = evidenceHash;
    }

    public String getVisibilityLevel() {
        return visibilityLevel;
    }

    public void setVisibilityLevel(String visibilityLevel) {
        this.visibilityLevel = visibilityLevel;
    }

    public boolean isBlocker() {
        return blocker;
    }

    public void setBlocker(boolean blocker) {
        this.blocker = blocker;
    }

    public String getBlockerReason() {
        return blockerReason;
    }

    public void setBlockerReason(String blockerReason) {
        this.blockerReason = blockerReason;
    }

    public String getNextExpectedStatus() {
        return nextExpectedStatus;
    }

    public void setNextExpectedStatus(String nextExpectedStatus) {
        this.nextExpectedStatus = nextExpectedStatus;
    }

    public String getUpdatedBy() {
        return updatedBy;
    }

    public void setUpdatedBy(String updatedBy) {
        this.updatedBy = updatedBy;
    }

    public String getNextExpectedEvent() {
        return nextExpectedEvent;
    }

    public void setNextExpectedEvent(String nextExpectedEvent) {
        this.nextExpectedEvent = nextExpectedEvent;
    }

}
