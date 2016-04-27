public with sharing class mbs_CampainMailerExtension {
    public mbs_CampainMailerExtension(ApexPages.StandardController stdController) {
        currentPage = 'EDIT';
        this.m_campaign = (Campaign)stdController.getRecord();
    }
    
    private Campaign m_campaign;
    public Boolean getIsEditPage() {
        return currentPage == 'EDIT';
    }
    public Boolean getIsPreviewPage() {
        return currentPage == 'PREVIEW';
    }
    public Boolean getIsResultPage() {
        return currentPage == 'RESULT';
    }
    
    private String InstanceUrl {
        get {
            if (InstanceUrl == null) {
                InstanceUrl = ApexPages.currentPage().getHeaders().get('X-Salesforce-Forwarded-To');
            }
            return InstanceUrl;
        }
        private set;
    }
    
    public List<mbs_EmailImage> EmailImages {
        get {
            if (EmailImages == null) {
                String folderName = 'Campaign Mailer Images';
                if (Test.isRunningTest()) {
                    folderName = 'Shared Documents';
                }
                String instanceUrl = InstanceUrl;
                EmailImages = new List<mbs_EmailImage>();
                List<Document> docs = [SELECT Id, Name, CreatedDate FROM Document where Folder.Name = :folderName AND IsPublic = true AND ContentType LIKE 'image%' 
                                       ORDER BY CreatedDate DESC];
                System.debug('docs=' + docs);
                for (Document doc : docs) {
                    EmailImages.add(new mbs_EmailImage(doc, instanceUrl));
                }
            }
            return EmailImages;
        }        
        private set;
    }
    
    private String EmailHeaderId {
        get {
            if (EmailHeaderId == null) {
           		TrueDaughtersSettings__c settings = TrueDaughtersSettings__c.getOrgDefaults();
                EmailHeaderId  = settings.EmailHeaderImageId__c;
            }
            return EmailHeaderId;
        }
        private set;
    }
 
    public Boolean mailMembers {get; set;}
    public Boolean mailMemberGuardians {get; set;}
    public String emailSubject {get;set;}
    public String emailBodyHtml {get;set;}
    public string currentPage {get;set;}
    public List<Contact> selectedMembers {get; set;}
    public List<npe4__Relationship__c> selectedGuardians {get; set;}    
    public List<Contact> sentContacts {get; private set;}    
    public List<Contact> didNotSend {get; private set;}  
    public String HtmlPreview {get; private set;}
    
    public void removeMemberFromList() {
        if (selectedMembers.size() == 1 && selectedGuardians.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'You must have at least one recipient.'));
            return;
        }
        ID memberId = Id.valueOf(apexpages.currentpage().getparameters().get('memberId'));
        for(integer i=0; i<selectedMembers.size(); i++) {
            if (selectedMembers[i].Id == memberId) {
                selectedMembers.remove(i);
                break;
            }
        }
    }
    
    public void removeGuardianFromList() {
        if (selectedGuardians.size() == 1 && selectedMembers.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'You must have at least one recipient.'));
            return;
        }
        ID guardianId = Id.valueOf(apexpages.currentpage().getparameters().get('guardianId'));
        System.debug('removeGuardianFromList id=' + guardianId);
        for(integer i=0; i<selectedGuardians.size(); i++) {
            System.debug('selectedGuardian[' + i + '].Id=' + selectedGuardians[i].Id);
            if (selectedGuardians[i].Id == guardianId) {
                selectedGuardians.remove(i);
                break;
            }
        }
    }   
    
    private void generateRecipientList() {
        System.debug('generateRecipientList()');
        selectedMembers = new List<Contact>();
        selectedGuardians = new List<npe4__Relationship__c>();
        Set<Id> guardianIds = new Set<Id>();
        List<Contact> allMembers = [SELECT Contact.Name, Contact.Email, Contact.HasOptedOutOfEmail, contact.EmailBouncedDate, Contact.FirstName,
                                    (SELECT npe4__RelatedContact__r.Name, npe4__RelatedContact__r.FirstName, npe4__RelatedContact__r.Email, npe4__Type__c, npe4__Relationship_Explanation__c,
                                     npe4__RelatedContact__r.HasOptedOutOfEmail, npe4__RelatedContact__r.EmailBouncedDate FROM npe4__Relationships__r ORDER BY npe4__RelatedContact__r.Name) 
                                    FROM Contact WHERE Id in (SELECT ContactId FROM CampaignMember WHERE CampaignId = :m_campaign.Id) ORDER BY Name];
        System.debug('allMembers=' + allMembers);
        for (Contact member : allMembers) {
            System.debug('member=' + member);
            if (mailMembers) {
                selectedMembers.add(member);
            }
            if (mailMemberGuardians && member.npe4__Relationships__r != null && member.npe4__Relationships__r.size() > 0) {
                npe4__Relationship__c guardian = findGuardian(member.npe4__Relationships__r, 'Mother');
                if (guardian == null) {
                    guardian = findGuardian(member.npe4__Relationships__r, 'Father');
                }
                if (guardian == null) {
                    guardian = findGuardian(member.npe4__Relationships__r, 'Grandmother');
                }
                if (guardian == null) {
                    guardian = findGuardian(member.npe4__Relationships__r, 'Grandfather');
                }
                if (guardian == null) {
                    guardian = member.npe4__Relationships__r[0];
                }
                System.debug('found guardian with id=' + guardian.Id);
                if (!guardianIds.contains(guardian.npe4__RelatedContact__c)) {
                    guardianIds.add(guardian.npe4__RelatedContact__c);
                    selectedGuardians.add(guardian);
                }
            }
        }
        selectedGuardians.sort();
    }
    
    private npe4__Relationship__c findGuardian(List<npe4__Relationship__c> guardians, String guardianType) {
        for (npe4__Relationship__c guardian : guardians) {
            if (guardian.npe4__Type__c == guardianType) {
                return guardian;
            }
        }
        return null;
    }
    
    public PageReference goBack() {
        currentPage = 'EDIT';
        return null;
    }

    public PageReference previewMailer() {
        if (!mailMembers && ! mailMemberGuardians) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'You must specify at least one recipient group.'));
            return null;
        }
        generateRecipientList();
        HtmlPreview = generateEmail('Jane', emailBodyHtml);
        //loadEmailTemplate();
        currentPage = 'PREVIEW';
        return null;
    }    
    
    private string generateEmail(String memberName, String emailBody) {
        string html = '<table width="100%" cellpadding="0" cellspacing="0" border="0" align="center">' +
            '<tr><td align="center">' +
            '<img alt="True Daughters - The Rise Up Effect" height="200" width="600" align="middle" src="https://' + InstanceUrl + '/servlet/servlet.ImageServer?id=' + EmailHeaderId + '&oid=' + UserInfo.getOrganizationId() + '" /><br/>' + 
			'</td></tr>' +
            '<tr><td><table align="center" style="font-family:Arial;font-size:11pt;color:#000000;" border="0" cellpadding="0" cellspacing="0" width="100%">' +
            '<tr><td>Dear&nbsp;' + memberName + ',<br/><br/></td></tr>' +
    		'<tr><td>' + emailBody + '</td></tr></table></td></tr><tr>' +
			'<td width="100%" style="font-family:Arial;font-size:9pt;color:#000000;text-align:center;"><br/><br/>' + getEmailFooter() + '</td></tr></table>';
        return html;
    }
    
    private string getEmailFooter() {      
        if (Test.isRunningTest()) {
            return '';
        }
        EmailServicesAddress address = [SELECT Id, LocalPart, EmailDomainName FROM EmailServicesAddress 
                                        WHERE FunctionId in (SELECT Id FROM EmailServicesFunction WHERE FunctionName = 'Unsubscribe Service')];
        
        string footerHtml = 'If you would no longer like to receive this type of email from True Daughters ' +
            '<a href="mailto:' + address.LocalPart + '@' + address.EmailDomainName + '?subject=unsubscribe&body=I wish to opt out of future emails.">click here</a>' + 
            ' to unsubscribe and click send on the resulting email.';
        return footerHtml;
    }
    
    public PageReference sendMail() {
        sentContacts = new List<Contact>();
        didNotSend = new List<Contact>();
        List<Messaging.SingleEmailMessage> emailMessages = new List<Messaging.SingleEmailMessage>();
        
        for (Contact member : selectedMembers) {        
            if (String.isNotEmpty(member.Email) && !member.HasOptedOutOfEmail && member.EmailBouncedDate == null) {
                sentContacts.add(member);
                Messaging.SingleEmailMessage emailMessage = new Messaging.SingleEmailMessage();
                emailMessage.setTargetObjectId(member.Id);      
                emailMessage.HtmlBody = generateEmail(member.FirstName, emailBodyHtml);
                emailMessage.Subject = emailSubject;
                emailMessage.setSaveAsActivity(true);
                emailMessages.add(emailMessage);
                if (emailMessages.size() == 100) {
                    sendBatchEmail(emailMessages);
                    emailMessages.clear();
                }
            }     
            else {
                didNotSend.add(member);
            }
        }
        for (npe4__Relationship__c guardian : selectedGuardians) {
            if (String.isNotEmpty(guardian.npe4__RelatedContact__r.Email) && !guardian.npe4__RelatedContact__r.HasOptedOutOfEmail && 
                guardian.npe4__RelatedContact__r.EmailBouncedDate == null) {
                sentContacts.add(guardian.npe4__RelatedContact__r);
                Messaging.SingleEmailMessage emailMessage = new Messaging.SingleEmailMessage();
                emailMessage.setTargetObjectId(guardian.npe4__RelatedContact__c);
                emailMessage.HtmlBody = generateEmail(guardian.npe4__RelatedContact__r.FirstName, emailBodyHtml);
                emailMessage.Subject = emailSubject;
                emailMessage.setSaveAsActivity(true);
                emailMessages.add(emailMessage);
                if (emailMessages.size() == 100) {
                    sendBatchEmail(emailMessages);
                    emailMessages.clear();
                }
            }    
            else {
                didNotSend.add(guardian.npe4__RelatedContact__r);
            }
        }
        if (emailMessages.size() > 0) {
            sendBatchEmail(emailMessages);
        }
        currentPage = 'RESULT';
        return null;
    }
    
    private void sendBatchEmail(List<Messaging.SingleEmailMessage> emailMessages) {
        if (emailMessages.isEmpty()) {
            return;
        }
        List<Messaging.SendEmailResult> results;
        try {
            results = Messaging.sendEmail(emailMessages);
        }catch(Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error Sending Email: ' + e.getMessage()));
        }
    }
}