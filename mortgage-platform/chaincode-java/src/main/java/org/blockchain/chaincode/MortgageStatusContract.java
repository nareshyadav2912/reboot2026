package org.blockchain.chaincode;

import com.owlike.genson.Genson;
import org.hyperledger.fabric.contract.Context;
import org.hyperledger.fabric.contract.ContractInterface;
import org.hyperledger.fabric.contract.annotation.Contract;
import org.hyperledger.fabric.contract.annotation.Default;
import org.hyperledger.fabric.contract.annotation.Info;
import org.hyperledger.fabric.contract.annotation.Transaction;
import org.hyperledger.fabric.shim.ChaincodeStub;

import java.nio.charset.StandardCharsets;

@Contract(name = "MortgageStatusContract", info = @Info(title = "Mortgage Status Contract", description = "Tracks mortgage conveyancing workflow", version = "1.0"))
@Default
public class MortgageStatusContract implements ContractInterface {

    private final Genson genson = new Genson();

    /**
     * Check whether a mortgage case exists.
     */
    @Transaction(intent = Transaction.TYPE.EVALUATE)
    public boolean caseExists(Context ctx, String caseId) {

        ChaincodeStub stub = ctx.getStub();

        String data = stub.getStringState(caseId);

        return data != null && !data.isEmpty();
    }

    /**
     * Create a new Mortgage Case.
     * Only Broker (Org1MSP) can create.
     */
    @Transaction(intent = Transaction.TYPE.SUBMIT)
    public void createCase(
            Context ctx,
            String caseId,
            String transactionId,
            String propertyReference,
            String buyerName,
            String sellerName,
            String brokerName,
            String lenderName,
            String conveyancerName,
            String estateAgentName) {

        ChaincodeStub stub = ctx.getStub();

        // Only Org1 can create mortgage cases
        String mspId = ctx.getClientIdentity().getMSPID();

        if (!"Org1MSP".equals(mspId)) {
            throw new RuntimeException("Only Broker (Org1MSP) can create mortgage cases.");
        }

        // Check if case already exists
        if (caseExists(ctx, caseId)) {
            throw new RuntimeException("Mortgage case already exists.");
        }

        MortgageCase mortgageCase = new MortgageCase();

        mortgageCase.setCaseId(caseId);
        mortgageCase.setTransactionId(transactionId);
        mortgageCase.setPropertyReference(propertyReference);

        mortgageCase.setBuyerName(buyerName);
        mortgageCase.setSellerName(sellerName);
        mortgageCase.setBrokerName(brokerName);
        mortgageCase.setLenderName(lenderName);
        mortgageCase.setConveyancerName(conveyancerName);
        mortgageCase.setEstateAgentName(estateAgentName);

        mortgageCase.setStatusCode(MortgageStatus.CASE_CREATED.name());
        mortgageCase.setStatusLabel("Case Created");

        mortgageCase.setUpdatedByRole("BROKER");
        mortgageCase.setUpdatedByOrg(mspId);

        mortgageCase.setUpdatedBy("System");
        mortgageCase.setUpdatedByUser("System");

        mortgageCase.setTimestamp(stub.getTxTimestamp().toString());

        mortgageCase.setConfidence("VERIFIED");
        mortgageCase.setEvidenceHash("");
        mortgageCase.setVisibilityLevel("NETWORK_STATUS_ONLY");

        mortgageCase.setBlocker(false);
        mortgageCase.setBlockerReason("");

        mortgageCase.setNextExpectedEvent(
                MortgageStatus.CONVEYANCER_ASSIGNED.name());

        mortgageCase.setNextExpectedStatus(
                MortgageStatus.CONVEYANCER_ASSIGNED.name());

        String mortgageJson = genson.serialize(mortgageCase);

        stub.putStringState(caseId, mortgageJson);

        // Publish blockchain event
        stub.setEvent(
                "CaseCreated",
                mortgageJson.getBytes(StandardCharsets.UTF_8));
    }

    @Transaction(intent = Transaction.TYPE.SUBMIT)
    public void updateStatus(
            Context ctx,
            String caseId,
            String newStatus,
            String updatedByUser,
            String confidence,
            String evidenceHash) {

        ChaincodeStub stub = ctx.getStub();

        // Read mortgage case
        MortgageCase mortgageCase = readCase(ctx, caseId);

        MortgageStatus currentStatus = MortgageStatus.valueOf(mortgageCase.getStatusCode());

        MortgageStatus nextStatus = MortgageStatus.valueOf(newStatus);

        // Validate workflow transition
        if (!MortgageStatusValidator.isValidTransition(currentStatus, nextStatus)) {
            throw new RuntimeException(
                    "Invalid transition from "
                            + currentStatus
                            + " to "
                            + nextStatus);
        }

        // Validate caller MSP
        String callerMSP = ctx.getClientIdentity().getMSPID();

        String requiredMSP = MortgageStatusValidator.getRequiredMSP(nextStatus);

        if (!requiredMSP.equals(callerMSP)) {
            throw new RuntimeException(
                    "Only "
                            + requiredMSP
                            + " can update status to "
                            + nextStatus);
        }

        // Update mortgage fields
        mortgageCase.setStatusCode(nextStatus.name());

        mortgageCase.setStatusLabel(
                nextStatus.name().replace("_", " "));

        mortgageCase.setUpdatedByRole(callerMSP);

        mortgageCase.setUpdatedByOrg(callerMSP);

        mortgageCase.setUpdatedBy(updatedByUser);

        mortgageCase.setUpdatedByUser(updatedByUser);

        mortgageCase.setTimestamp(stub.getTxTimestamp().toString());

        mortgageCase.setConfidence(confidence);

        mortgageCase.setEvidenceHash(evidenceHash);

        mortgageCase.setVisibilityLevel("NETWORK_STATUS_ONLY");

        mortgageCase.setNextExpectedStatus(getNextStatus(nextStatus));

        mortgageCase.setNextExpectedEvent(getNextStatus(nextStatus));

        // Save
        String json = genson.serialize(mortgageCase);

        stub.putStringState(caseId, json);

        // Blockchain event
        stub.setEvent(
                "StatusUpdated",
                json.getBytes(StandardCharsets.UTF_8));
    }

    /**
     * Read Mortgage Case.
     */
    @Transaction(intent = Transaction.TYPE.EVALUATE)
    public MortgageCase readCase(Context ctx, String caseId) {

        ChaincodeStub stub = ctx.getStub();

        String mortgageJson = stub.getStringState(caseId);

        if (mortgageJson == null || mortgageJson.isEmpty()) {
            throw new RuntimeException("Mortgage case not found.");
        }

        return genson.deserialize(mortgageJson, MortgageCase.class);
    }

    private String getNextStatus(MortgageStatus status) {

    switch (status) {

        case CASE_CREATED:
            return MortgageStatus.CONVEYANCER_ASSIGNED.name();

        case CONVEYANCER_ASSIGNED:
            return MortgageStatus.TITLE_CHECKS_IN_PROGRESS.name();

        case TITLE_CHECKS_IN_PROGRESS:
            return MortgageStatus.TITLE_CHECKS_COMPLETED.name();

        case TITLE_CHECKS_COMPLETED:
            return MortgageStatus.SEARCHES_ORDERED.name();

        case SEARCHES_ORDERED:
            return MortgageStatus.SEARCHES_RECEIVED.name();

        case SEARCHES_RECEIVED:
            return MortgageStatus.ENQUIRIES_RAISED.name();

        case ENQUIRIES_RAISED:
            return MortgageStatus.ENQUIRIES_RESOLVED.name();

        case ENQUIRIES_RESOLVED:
            return MortgageStatus.MORTGAGE_OFFER_RECEIVED.name();

        case MORTGAGE_OFFER_RECEIVED:
            return MortgageStatus.READY_TO_EXCHANGE.name();

        case READY_TO_EXCHANGE:
            return MortgageStatus.CONTRACTS_EXCHANGED.name();

        case CONTRACTS_EXCHANGED:
            return MortgageStatus.READY_TO_COMPLETE.name();

        case READY_TO_COMPLETE:
            return MortgageStatus.COMPLETED.name();

        case COMPLETED:
            return "NONE";

        default:
            return "UNKNOWN";
    }
}
}