package org.blockchain.chaincode;

import com.owlike.genson.Genson;
import org.hyperledger.fabric.contract.Context;
import org.hyperledger.fabric.contract.ContractInterface;
import org.hyperledger.fabric.contract.annotation.Contract;
import org.hyperledger.fabric.contract.annotation.Default;
import org.hyperledger.fabric.contract.annotation.Info;
import org.hyperledger.fabric.contract.annotation.Transaction;
import org.hyperledger.fabric.shim.ChaincodeStub;

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
     * Check whether a mortgage case exists
     */
    @Transaction(intent = Transaction.TYPE.EVALUATE)
    public boolean caseExists(Context ctx, String caseId) {

        ChaincodeStub stub = ctx.getStub();

        String data = stub.getStringState(caseId);

        return data != null && !data.isEmpty();
    }

    /**
     * Create Mortgage Case
     */
    @Transaction
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

        if (caseExists(ctx, caseId)) {
            throw new RuntimeException("Mortgage case already exists");
        }

        MortgageCase mortgageCase = new MortgageCase(
                caseId,
                transactionId,
                propertyReference,
                buyerName,
                sellerName,
                brokerName,
                lenderName,
                conveyancerName,
                estateAgentName,
                MortgageStatus.CASE_CREATED.name(),
                "Case Created",
                "Broker",
                brokerName,
                "System",
                stub.getTxTimestamp().toString(),
                "VERIFIED",
                "",
                "NETWORK_STATUS_ONLY",
                false,
                "",
                MortgageStatus.CONVEYANCER_ASSIGNED.name()
        );

        stub.putStringState(caseId, genson.serialize(mortgageCase));
    }

    /**
     * Read Mortgage Case
     */
    @Transaction(intent = Transaction.TYPE.EVALUATE)
    public MortgageCase readCase(Context ctx, String caseId) {

        ChaincodeStub stub = ctx.getStub();

        String mortgageJSON = stub.getStringState(caseId);

        if (mortgageJSON == null || mortgageJSON.isEmpty()) {
            throw new RuntimeException("Mortgage case not found");
        }

        return genson.deserialize(mortgageJSON, MortgageCase.class);
    }
}