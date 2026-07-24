package org.blockchain.chaincode;

import java.util.Map;

public class MortgageStatusValidator {

    private MortgageStatusValidator() {
    }

    private static final Map<MortgageStatus, MortgageStatus> ALLOWED_TRANSITIONS = Map.ofEntries(

            Map.entry(MortgageStatus.CASE_CREATED,
                    MortgageStatus.CONVEYANCER_ASSIGNED),

            Map.entry(MortgageStatus.CONVEYANCER_ASSIGNED,
                    MortgageStatus.TITLE_CHECKS_IN_PROGRESS),

            Map.entry(MortgageStatus.TITLE_CHECKS_IN_PROGRESS,
                    MortgageStatus.TITLE_CHECKS_COMPLETED),

            Map.entry(MortgageStatus.TITLE_CHECKS_COMPLETED,
                    MortgageStatus.SEARCHES_ORDERED),

            Map.entry(MortgageStatus.SEARCHES_ORDERED,
                    MortgageStatus.SEARCHES_RECEIVED),

            Map.entry(MortgageStatus.SEARCHES_RECEIVED,
                    MortgageStatus.ENQUIRIES_RAISED),

            Map.entry(MortgageStatus.ENQUIRIES_RAISED,
                    MortgageStatus.ENQUIRIES_RESOLVED),

            Map.entry(MortgageStatus.ENQUIRIES_RESOLVED,
                    MortgageStatus.MORTGAGE_OFFER_RECEIVED),

            Map.entry(MortgageStatus.MORTGAGE_OFFER_RECEIVED,
                    MortgageStatus.READY_TO_EXCHANGE),

            Map.entry(MortgageStatus.READY_TO_EXCHANGE,
                    MortgageStatus.CONTRACTS_EXCHANGED),

            Map.entry(MortgageStatus.CONTRACTS_EXCHANGED,
                    MortgageStatus.READY_TO_COMPLETE),

            Map.entry(MortgageStatus.READY_TO_COMPLETE,
                    MortgageStatus.COMPLETED)

    );

    private static final Map<MortgageStatus, String> STATUS_OWNER = Map.ofEntries(

            Map.entry(MortgageStatus.CONVEYANCER_ASSIGNED, "Org3MSP"),
            Map.entry(MortgageStatus.TITLE_CHECKS_IN_PROGRESS, "Org3MSP"),
            Map.entry(MortgageStatus.TITLE_CHECKS_COMPLETED, "Org3MSP"),
            Map.entry(MortgageStatus.SEARCHES_ORDERED, "Org3MSP"),
            Map.entry(MortgageStatus.SEARCHES_RECEIVED, "Org3MSP"),
            Map.entry(MortgageStatus.ENQUIRIES_RAISED, "Org3MSP"),
            Map.entry(MortgageStatus.ENQUIRIES_RESOLVED, "Org3MSP"),

            Map.entry(MortgageStatus.MORTGAGE_OFFER_RECEIVED, "Org2MSP"),

            Map.entry(MortgageStatus.READY_TO_EXCHANGE, "Org3MSP"),
            Map.entry(MortgageStatus.CONTRACTS_EXCHANGED, "Org3MSP"),

            Map.entry(MortgageStatus.READY_TO_COMPLETE, "Org4MSP"),

            Map.entry(MortgageStatus.COMPLETED, "Org3MSP")

    );

    public static boolean isValidTransition(
            MortgageStatus current,
            MortgageStatus next) {

        return ALLOWED_TRANSITIONS.get(current) == next;
    }

    public static String getRequiredMSP(MortgageStatus status) {
        return STATUS_OWNER.get(status);
    }
}