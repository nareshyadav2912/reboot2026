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

@Contract(
        name = "MortgageStatusContract",
        info = @Info(
                title = "Mortgage Status Contract",
                description = "Tracks mortgage conveyancing workflow",
                version = "1.0"
        )
)
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

        mortgageCase.setTimestamp(stub.getTxTimestamp().toString());

        mortgageCase.setConfidence("VERIFIED");
        mortgageCase.setEvidenceHash("");
        mortgageCase.setVisibilityLevel("NETWORK_STATUS_ONLY");

        mortgageCase.setBlocker(false);
        mortgageCase.setBlockerReason("");

        mortgageCase.setNextExpectedEvent(
                MortgageStatus.CONVEYANCER_ASSIGNED.name());

        String mortgageJson = genson.serialize(mortgageCase);

        stub.putStringState(caseId, mortgageJson);

        // Publish blockchain event
        stub.setEvent(
                "CaseCreated",
                mortgageJson.getBytes(StandardCharsets.UTF_8));
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
}