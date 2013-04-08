/**************************************************
Class Name: OpenOpportunityEmailUtils
Class Description: Utiliy class which creates the HTML content to be displayed on the email / VF page.  
Author: Fernando Rodriguez (frodriguez@adooxen.com)
Modified By: Fernando
Update Date: 2013-03-04
Additional Comments: This class has comments on the code in order to help future changes   
**************************************************/
public with sharing class OpenOpportunityEmailUtils {


    private static String[] earlyStages = new String[] {'Stage 1 - Connect','Stage 2 - Talking','Stage 5 - Submitted'};
    
    
    /**************************************************
    Comments: Static variables that represents the diferent containers for the email / VF page HTML components
    **************************************************/                            
    private static String ENVELOPE = '<div>[TITLE][CONTAINER]</div>';    
    private static String TITLE = '<div><table border="0" cellpadding="0" cellspacing="0"><tr><td><h2>Open Opportunities</h2></td></tr></table></div>';
    private static String SUB_TITLE = '<tr><th style="background-color:#9bb1d9;color:white;text-align:left;padding-left:5px"><label>[SUB_TITLE]</label></th></tr>';
    private static String CONTAINER = '<div><table class="container-stage-table" style="width:100%">[SUB_CONTAINER]</table></div>';

    private static final String FOGBUGZ_LINK = 'http://manage.dimagi.com/default.asp?';

	/**************************************************
	Method Name: buildEmailContent
	Method Comments: Method call from the Weekly / Daily Schedule flow to build the HTML Content   
	**************************************************/
    public static String buildEmailContent(Map<String, Opportunity[]> stagedOpportunities, Boolean hasComments, Map<String, String> stageComments) {
        
        String result = ENVELOPE;
        String content = '';
        
        List<String> sortedStages = new List<String>(stagedOpportunities.keySet());
        sortedStages.sort();
        
        for(String stageName :sortedStages) {           
            
            String stageTable = '<tr><table class="main-stage-table" style="width:100%;border:1px solid #E3DEB8;">' + SUB_TITLE.replace('[SUB_TITLE]', stageName);
            
            /**************************************************
			Comments: for each stage we call buildEmailStageTable     
			**************************************************/
            stageTable += '<tr><td>' + buildEmailStageTable(stageName, stagedOpportunities.get(stageName)) + '</td></tr>';
                        
            /**************************************************
            Comments: for each stage we call getEmailStageComments (if there are no comments, the input text is generated anyway)
            **************************************************/                        
            stageTable += '<tr><td>' + getEmailStageComments(stageComments.get(stageName)) + '</td></tr>';
                        
            stageTable += '</table></tr>';            
            stageTable = stageTable.replace('null', '');
            content += stageTable;                                  
        }       
        
        result = result.replace('[TITLE]', TITLE);
        return result.replace('[CONTAINER]', CONTAINER.replace('[SUB_CONTAINER]', content));        
    }

	/**************************************************
	Method Name: buildEmailStageTable
	Method Comments: Method which returns the content of a HTML table for a Stage   
	**************************************************/
    public static String buildEmailStageTable(String stageName, Opportunity[] opportunities) {
        
        String result = '<table class="stage-table" cellspacing="0" style="width:100%;border:1px solid #e0e3e5">[THEADER][TBODY]</table>';      
        result = result.replace('[THEADER]', getEmailStageTableHeader());
        
        String tbody = '';
        
        Integer daysNotUpdatedLimit = Open_Opportunity_Settings__c.getOrgDefaults().Days_Not_Updated_Limit__c != null 
                                       ? Open_Opportunity_Settings__c.getOrgDefaults().Days_Not_Updated_Limit__c.intValue()
                                       : 30;
                                       
        Integer daysNotUpdatedLimitEarlyStages = Open_Opportunity_Settings__c.getOrgDefaults().Days_Not_Updated_Limit_Early_Stages__c != null 
                                       ? Open_Opportunity_Settings__c.getOrgDefaults().Days_Not_Updated_Limit_Early_Stages__c.intValue()
                                       : 10;        
        
        Set<String> earlyStagesSet = new Set<String>(earlyStages);
        
        for(Opportunity opp :opportunities) {
            tbody += getEmailStageTableRow(opp, daysNotUpdatedLimit, daysNotUpdatedLimitEarlyStages, earlyStagesSet);
        }       
        result = result.replace('[TBODY]', tbody).replace('null', '');
        return result;
    }

	/**************************************************
	Method Name: getEmailStageTableHeader
	Method Comments: Returns the header of the stage tables, depending on which columns where selected   
	**************************************************/
    private static String getEmailStageTableHeader() {        
        
        final String LEFT_STYLE = 'style="background:#f2f3f3;text-align:left"';
        final String RIGHT_STYLE = 'style="background:#f2f3f3;text-align:right"'; 
        
        String result =  '<tr>';
        
        /**************************************************
        Comments: Fetches the columns from the Custom Settings
        **************************************************/         
        Open_Opportunity_Fields__c[] selectedFields = OpenOpportunityReportController.getOpportunityFields();
        
        if (!selectedFields.isEmpty()) {
            
            result += '<th [LEFT_STYLE]>Opportunity Name</th>';
            for(Open_Opportunity_Fields__c selectedField :selectedFields) {
                
                result += '<th [RIGHT_STYLE]>' + selectedField.Label__c + '</th>';
            }           
        }
        else {
                        
            result += '<th [LEFT_STYLE]>Opportunity Name</th>' +
                        '<th [RIGHT_STYLE]>Stage Duration</th>' +
                        '<th [RIGHT_STYLE]>Fogbugz Ticket Number</th>' +
                        '<th [RIGHT_STYLE]>Fogbugz Assigned To</th>' +
                        '<th [RIGHT_STYLE]>Probability (%)</th>' +
                        '<th [RIGHT_STYLE]>Amount</th>' +
                        '<th [RIGHT_STYLE]>Account Name</th>' +
                        '<th [RIGHT_STYLE]>Business Unit Owner</th>' +
                        '<th [RIGHT_STYLE]>Days not Updated</th>';
        }        
        result += '</tr>';
                            
                
        return result.replace('[LEFT_STYLE]', LEFT_STYLE).replace('[RIGHT_STYLE]', RIGHT_STYLE);
    }

	/**************************************************
	Method Name: getEmailStageTableRow
	Method Comments: method called from buildEmailStageTable. For each opportunity this method is called. Renders the status of the opportunity and its data.    
	**************************************************/
    private static String getEmailStageTableRow(Opportunity opp, Integer daysNotUpdatedLimit, Integer daysNotUpdatedLimitEarlyStages, Set<String> earlyStagesSet) {
        
        final String LEFT_STYLE = 'style="border-width:0 0 1px 0;vertical-align:middle;padding:4px 2px 4px 5px;border-bottom:1px solid #e3deb8;"';
        final String STYLE = 'style="border-width:0 0 1px 0;vertical-align:middle;padding:4px 2px 4px 5px;border-bottom:1px solid #e3deb8;text-align:right"'; 
        String rowStart = '';
        
        /**************************************************
        Comments: Filtering process in order to define the style of the Opportunity Row (red, yellow, etc)
        **************************************************/
        if (opp.AccountId == null) {        	
        	rowStart = '<tr style="background:#F3F781">';
        }
        else {
        	rowStart = '<tr>';
        }        
        
        // added by Nick - checking if it is a long wait after submission
        
		if (opp.StageName.contains('Submitted') && opp.long_wait__c) {
			rowStart = rowStart;
		}
		else {
		// end added by Nick
			
        if (earlyStagesSet.contains(opp.StageName)) {            
            rowStart = opp.Total_Days_Not_Updated__c > daysNotUpdatedLimitEarlyStages 
                                   ? '<tr style="background:#E9967A">' 
                                   : rowStart;
        }
        else {
            rowStart = opp.Total_Days_Not_Updated__c > daysNotUpdatedLimit 
                                   ? '<tr style="background:#E9967A">' 
                                   : rowStart;
        }
        }
        
        String href = URL.getSalesforceBaseUrl().toExternalForm() + '/' + String.valueOf(opp.Id);
        
        Open_Opportunity_Fields__c[] selectedFields = OpenOpportunityReportController.getOpportunityFields();
        String result =  rowStart;
        
        if (!selectedFields.isEmpty()) {
            
	        /**************************************************
	        Comments: This loop goes over the Opportunity fields (based on the selected columns) and 
	                   formats the different fields (datetime, float, link, etc)
	        **************************************************/            
            result += '<td [LEFT_STYLE]><span><a href="' + href + '" target="_blank">' + opp.Name + '</a></span></td>';
            for(Open_Opportunity_Fields__c selectedField :selectedFields) {                             
                           
                try {                          
                           
                    String fieldType = selectedField.Type__c;
                    
                    String fieldValue = '';
                    if (selectedField.Name.equals('Owner.Name')) {                         
                        fieldValue = opp.Owner.Name;
                    }
                    else {
                        fieldValue = String.valueOf(opp.get(selectedField.Name));
                    }
                    
                    if (fieldType.equalsIgnoreCase('Date')) {         
                        fieldValue = opp.get(selectedField.Name) != null 
                                      ? Date.valueOf(opp.get(selectedField.Name)).format() 
                                      : '';                                
                    }
                    else if (fieldType.equalsIgnoreCase('DateTime')) {
                        fieldValue = opp.get(selectedField.Name) != null 
                                      ? Datetime.valueOf(opp.get(selectedField.Name)).format('MM/dd/yyyy HH:mm a') 
                                      : '';
                    }
                    else if (fieldType.equalsIgnoreCase('Currency')) {
                        
                        fieldValue = '';
                        if (opp.get(selectedField.Name) != null) {
                            
                            List<String> args = new String[]{'0','number','###,###,##0.00'};    
                            Decimal currencyValue = (Decimal) opp.get(selectedField.Name);
                            fieldValue = '$' + String.format(currencyValue.format(), args);                         
                        }
                    }
                    
                    if (selectedField.Name.equals('Fogbugz_Ticket_Number__c')) {
                        result += '<td [STYLE]><span><a href="' + FOGBUGZ_LINK + fieldValue 
                                + '" target="_blank">' + fieldValue + '</a></span></td>';
                    }
                    else {
                        result += '<td [STYLE]><span>' + fieldValue + '</span></td>';
                    }
                }
                catch (Exception e) {}    
            }
        }
        else {
            /**************************************************
            Comments: When the selectedFields list is empty, that means we need to display 
                       the default columns, which are already defined below. 
                       We don;t need to make a custom format treatment as above, as we already know which columns are selected.
            **************************************************/   
            String amountValue = '';
            if (opp.Amount != null) {
                List<String> args = new String[]{'0','number','###,###,##0.00'};
                amountValue = '$' + String.format(opp.Amount.format(), args);
            }

            result += '<td [LEFT_STYLE]><span><a href="' + href + '" target="_blank">' + opp.Name + '</a></span></td>' +
                        '<td [STYLE]><span>' + opp.Stage_Duration__c + '</span></td>' +
                        '<td [STYLE]><span><a href="' + opp.Fogbugz_Link__c + '" target="_blank">' + opp.Fogbugz_Ticket_Number__c + '</a></span></td>' +
                        '<td [STYLE]><span>' + opp.Fogbugz_Assigned_To__c + '</span></td>' +
                        '<td [STYLE]><span>' + opp.Fogbugz_Probability__c + '</span></td>' +
                        '<td [STYLE]><span>' + amountValue + '</span></td>' +
                        '<td [STYLE]><span>' + opp.Account.Name + '</span></td>' +
                        '<td [STYLE]><span>' + opp.Business_Unit_Owner__r.Name + '</span></td>' + 
                        '<td [STYLE]><span>' + opp.Total_Days_Not_Updated__c + '</span></td>';
        }
            
        result += '</tr>';
                        
        return result.replace('[STYLE]', STYLE).replace('[LEFT_STYLE]', LEFT_STYLE);                        
    }
    
	/**************************************************
	Method Name: getEmailStageComments
	Method Comments: This method is called from buildEmailContent method, in order to add to the email comments written on the UI.     
	**************************************************/    
    private static String getEmailStageComments(String comments) {
        
        String headerRow = '<tr><th style="border:1px solid #e0e3e5;text-align:left;padding-left:5px;background-color:#E0E3E5;"><label> Comments </label></th></tr>';
        
        String dataComment = (comments != null &&  comments.trim().length() > 0) ? comments : '&nbsp;'; 
        
        String dataRow = '<tr><td style="border-width:0 0 1px 0;vertical-align:middle;padding:4px 2px 4px 5px;border-bottom:1px solid #e3deb8">' +
                          dataComment +  
                         '</td></tr>';
                         
        return '<table width="100%" style="1px solid #E0E3E5">' + headerRow + dataRow + '</table>';
    }
    
   
}