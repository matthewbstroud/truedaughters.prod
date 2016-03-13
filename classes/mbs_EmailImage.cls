public class mbs_EmailImage {
    private Document m_doc;
    private string m_instanceUrl;
    public mbs_EmailImage(Document doc, String instanceUrl) {
        m_doc = doc;
        m_instanceUrl = instanceUrl;
    }
    public string Name {
        get {
            if (m_doc == null) {
                return null;
            }
            return m_doc.Name;
        }
        private set;
    }
    public String CreatedDate {
        get {
            if (m_doc == null) {
                return null;
            }
            return m_doc.CreatedDate.format();
        }
        private set;
    }
    public string ExternalLink {
        get {
            if (ExternalLink == null && m_doc != null) {
                ExternalLink = 'https://' + m_instanceUrl + '/servlet/servlet.ImageServer?id=' + m_doc.Id + '&oid=' + UserInfo.getOrganizationId();
            }
        	return ExternalLink;
        }
        private set;
    }
}