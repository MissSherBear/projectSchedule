public with sharing class ProjectScheduleController {

    // Helper method to format a Decimal as currency
    public static String formatCurrency(Decimal value) {
        if (value != null) {
            return '$' + value.setScale(2).format();
        }
        return '';
    }

    // Helper method to format a Decimal as percentage
    public static String formatPercentage(Decimal value) {
        if (value != null) {
            return value.setScale(2).format() + '%';
        }
        return '';
    }

    @AuraEnabled
    public static void updateActivityDate(Id activityId, String fieldName, String newValue) {
        // Ensure that the input values are valid
        if (activityId == null || String.isEmpty(fieldName) || String.isEmpty(newValue)) {
            throw new AuraHandledException('Invalid input parameters');
        }

        sitetracker__Activity__c activityToUpdate = [
            SELECT Id, Start_Date_F__c, Start_A__c, sitetracker__Forecast_Date__c, sitetracker__ActualDate__c 
            FROM sitetracker__Activity__c
            WHERE Id = :activityId
            LIMIT 1
        ];

        if (fieldName == 'startDateF') {
            activityToUpdate.Start_Date_F__c = Date.valueOf(newValue);
        } else if (fieldName == 'startDateA') {
            activityToUpdate.Start_A__c = Date.valueOf(newValue);
        } else if (fieldName == 'forecastDate') {
            activityToUpdate.sitetracker__Forecast_Date__c = Date.valueOf(newValue);
        } else if (fieldName == 'actualDate') {
            activityToUpdate.sitetracker__ActualDate__c = Date.valueOf(newValue);
        } else {
            throw new AuraHandledException('Field name not recognized');
        }

        // Update the record in the database
        try {
            update activityToUpdate;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to update the activity date: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<SectionNode> getProjectActivities(String projectId) {
        List<SectionNode> projectActivities = new List<SectionNode>();

        // Query Activities grouped by Activity Section
        List<sitetracker__Activity__c> activities = [
            SELECT Id, Name, sitetracker__Activity_Section__c, sitetracker__Activity_Status__c, Total_Est_Committed_Cost__c, 
                   Total_Est_Committed_of_Current_Budget__c, Original_Budget_Cost__c, Current_Budget_Cost__c, WBS_Activity__c,
                   Start_Date_F__c, Start_A__c, sitetracker__Forecast_Date__c, sitetracker__ActualDate__c, 
                   Actual_MHr__c, Remaining_MHr__c
            FROM sitetracker__Activity__c 
            WHERE sitetracker__Project__c = :projectId
            ORDER BY sitetracker__Activity_Section__c, WBS_Activity__c ASC
        ];

        // Map to hold sections and their activities
        Map<String, SectionNode> sectionMap = new Map<String, SectionNode>();
        
        for (sitetracker__Activity__c activity : activities) {
            String section = activity.sitetracker__Activity_Section__c;

            // Query Finance Lines related to the activity
            List<sitetracker__Finance__c> financeLines = [
                SELECT Id, Name, sitetracker__PO_Line_Item__c, Estimated_Amount__c, CMTD_EXT_Cost__c, CMTD_INT_Cost__c, CMTD_Labor_Cost__c, 
                       Short_Description__c, Actual_MHr__c, Remaining_MHr__c
                FROM sitetracker__Finance__c 
                WHERE CGX_Activity__c = :activity.Id
            ];

            // Ensure section node exists
            if (!sectionMap.containsKey(section)) {
                SectionNode sectionNode = new SectionNode();
                sectionNode.id = 'section-' + section; // Unique ID for section
                sectionNode.name = section != null ? section : 'No Section';
                sectionNode.activities = new List<ActivityNode>(); // Create an empty list of activities
                sectionMap.put(section, sectionNode);
            } 
            
            // Create activity node
            ActivityNode activityNode = new ActivityNode();
            activityNode.id = activity.Id;  // Unique ID for activity
            activityNode.name = activity.Name;
            activityNode.wbsActivity = activity.WBS_Activity__c; 
            activityNode.activityStatus = activity.sitetracker__Activity_Status__c; 
            activityNode.startDateF = activity.Start_Date_F__c;
            activityNode.startDateA = activity.Start_A__c;
            activityNode.forecastDate = activity.sitetracker__Forecast_Date__c;
            activityNode.actualDate = activity.sitetracker__ActualDate__c;
            // Format dates as strings for display
            activityNode.formattedStartDateF = activity.Start_Date_F__c != null ? activity.Start_Date_F__c.format() : '';
            activityNode.formattedStartDateA = activity.Start_A__c != null ? DateTime.newInstance(activity.Start_A__c, Time.newInstance(0, 0, 0, 0)).format() : '';
            activityNode.formattedForecastDate = activity.sitetracker__Forecast_Date__c != null ? activity.sitetracker__Forecast_Date__c.format() : '';
            activityNode.formattedActualDate = activity.sitetracker__ActualDate__c != null ? activity.sitetracker__ActualDate__c.format() : '';
            // Assign decimal values as usual (checking for nulls)
            activityNode.estimatedCost = activity.Total_Est_Committed_Cost__c != null ? activity.Total_Est_Committed_Cost__c : 0;
            activityNode.originalBudget = activity.Original_Budget_Cost__c != null ? activity.Original_Budget_Cost__c : 0;
            activityNode.currentBudget = activity.Current_Budget_Cost__c != null ? activity.Current_Budget_Cost__c : 0;
            activityNode.percent = activity.Total_Est_Committed_of_Current_Budget__c != null ? activity.Total_Est_Committed_of_Current_Budget__c : 0;
            // activityNode.budgetMhr = activity.Budget_MHr__c != null ? activity.Budget_MHr__c : 0;
            activityNode.actualMhr = activity.Actual_MHr__c != null ? activity.Actual_MHr__c : 0;
            activityNode.remainingMhr = activity.Remaining_MHr__c != null ? activity.Remaining_MHr__c : 0;

            // Log the values for debugging purposes
            System.debug('Estimated Cost: ' + activity.Total_Est_Committed_Cost__c);
            System.debug('Original Budget: ' + activity.Original_Budget_Cost__c);
            System.debug('Current Budget: ' + activity.Current_Budget_Cost__c);
            System.debug('Percent: ' + activity.Total_Est_Committed_of_Current_Budget__c);

            // Manually format the values
            activityNode.formattedEstimatedCost = formatCurrency(activity.Total_Est_Committed_Cost__c);
            activityNode.formattedOriginalBudget = formatCurrency(activity.Original_Budget_Cost__c);
            activityNode.formattedCurrentBudget = formatCurrency(activity.Current_Budget_Cost__c);
            activityNode.formattedPercent = formatPercentage(activity.Total_Est_Committed_of_Current_Budget__c);

            // Add finance lines to the activity
            activityNode.financeLines = new List<FinanceNode>();
            for (sitetracker__Finance__c finance : financeLines) {
                FinanceNode financeNode = new FinanceNode();
                financeNode.id = 'finance-' + finance.Id;  // Unique ID for finance line
                financeNode.name = finance.Name + ' - ' + finance.sitetracker__PO_Line_Item__c;  
                financeNode.article = finance.sitetracker__PO_Line_Item__c;  
                financeNode.shortDescription = finance.Short_Description__c;
                financeNode.myDescription = 'Estimated Amount: ' + finance.Estimated_Amount__c + '\n' +
                                               'Estimated EXT Cost: ' + finance.CMTD_EXT_Cost__c + '\n' +
                                               'Estimated INT Cost: ' + finance.CMTD_INT_Cost__c + '\n' +
                                               'Total Estimated Cost: ' + finance.CMTD_Labor_Cost__c;
                // Log finance values for debugging purposes
                System.debug('CMTD EXT Cost: ' + finance.CMTD_EXT_Cost__c);
                System.debug('CMTD INT Cost: ' + finance.CMTD_INT_Cost__c);
                System.debug('CMTD Labor Cost: ' + finance.CMTD_Labor_Cost__c);

                // Assign decimal values as usual (checking for nulls)
                financeNode.cmtdExtCost = finance.CMTD_EXT_Cost__c != null ? finance.CMTD_EXT_Cost__c : 0;
                financeNode.cmtdIntCost = finance.CMTD_INT_Cost__c != null ? finance.CMTD_INT_Cost__c : 0;
                financeNode.estimatedCost = finance.CMTD_Labor_Cost__c != null ? finance.CMTD_Labor_Cost__c : 0;
                // financeNode.budgetMhr = finance.Budget_MHr__c != null ? finance.Budget_MHr__c : 0;
                financeNode.actualMhr = finance.Actual_MHr__c != null ? finance.Actual_MHr__c : 0;
                financeNode.remainingMhr = finance.Remaining_MHr__c != null ? finance.Remaining_MHr__c : 0;

                // Manually format the values
                financeNode.formattedCmtdExtCost = formatCurrency(finance.CMTD_EXT_Cost__c);
                financeNode.formattedCmtdIntCost = formatCurrency(finance.CMTD_INT_Cost__c);
                financeNode.formattedEstimatedCost = formatCurrency(finance.CMTD_Labor_Cost__c);
  
                activityNode.financeLines.add(financeNode);
            }

            // Add activity to its section
            sectionMap.get(section).activities.add(activityNode);
        }

        // Add all section nodes to the tree data
        projectActivities.addAll(sectionMap.values());

        return projectActivities;
    }

    // SectionNode class representing the sections in the table
    public class SectionNode {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public List<ActivityNode> activities { get; set; }  // List of activities within the section
    }

    // ActivityNode class representing each activity under a section
    public class ActivityNode {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String wbsActivity { get; set; }  
        @AuraEnabled public String activityStatus { get; set; }  
        @AuraEnabled public Decimal estimatedCost { get; set; }  
        @AuraEnabled public Decimal originalBudget { get; set; }
        @AuraEnabled public Decimal currentBudget { get; set; }
        @AuraEnabled public Decimal percent { get; set; }
        @AuraEnabled public Date startDateF { get; set; }
        @AuraEnabled public Date startDateA { get; set; }
        @AuraEnabled public Date forecastDate { get; set; }
        @AuraEnabled public Date actualDate { get; set; }
        @AuraEnabled public Decimal budgetMhr { get; set; }
        @AuraEnabled public Decimal actualMhr { get; set; }
        @AuraEnabled public Decimal remainingMhr { get; set; }

        // New fields for formatted dates
        @AuraEnabled public String formattedStartDateF { get; set; }
        @AuraEnabled public String formattedStartDateA { get; set; }
        @AuraEnabled public String formattedForecastDate { get; set; }
        @AuraEnabled public String formattedActualDate { get; set; }

        // Fields for formatted currency/percentage 
        @AuraEnabled public String formattedEstimatedCost { get; set; }  
        @AuraEnabled public String formattedOriginalBudget { get; set; }  
        @AuraEnabled public String formattedCurrentBudget { get; set; }  
        @AuraEnabled public String formattedPercent { get; set; }  
        @AuraEnabled public List<FinanceNode> financeLines { get; set; }  // List of finance lines for each activity
    }

    // FinanceNode class representing finance lines under each activity
    public class FinanceNode {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String article { get; set; }  
        @AuraEnabled public String shortDescription { get; set; } 
        @AuraEnabled public String myDescription { get; set; }  
        @AuraEnabled public Decimal cmtdExtCost { get; set; }  
        @AuraEnabled public Decimal cmtdIntCost { get; set; } 
        @AuraEnabled public Decimal estimatedCost { get; set; }  
        @AuraEnabled public Decimal budgetMhr { get; set; }
        @AuraEnabled public Decimal actualMhr { get; set; }
        @AuraEnabled public Decimal remainingMhr { get; set; }

        // New fields for formatted display
        @AuraEnabled public String formattedCmtdExtCost { get; set; }
        @AuraEnabled public String formattedCmtdIntCost { get; set; }
        @AuraEnabled public String formattedEstimatedCost { get; set; }
    }
}
