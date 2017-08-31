using System;
using System.Web;

namespace SAP.BusinessOne.Web
{
    public class Identity : IHttpHandler
    {
        /// <summary>
        /// You will need to configure this handler in the Web.config file of your 
        /// web and register it with IIS before being able to use it. For more information
        /// see the following link: http://go.microsoft.com/?linkid=8101007
        /// </summary>
        #region IHttpHandler Members

        public bool IsReusable
        {
            // Return false in case your Managed Handler cannot be reused for another request.
            // Usually this would be false in case you have some state information preserved per request.
            get { return true; }
        }

        public void ProcessRequest(HttpContext context)
        {
            DomainUser user = null;
            int i = 0;
            while (user == null && i < 5)
            {
                try
                {
                    user = new DomainUser(context.Request.LogonUserIdentity.Name);
                    break;
                }
                catch
                {
                    i++;
                }
            }

            var callback = context.Request.Url.Query;
            if (callback.StartsWith("?"))
                callback = callback.Substring(1);

            var script = string.Format("{0}('{1}','{2}')", callback, user.DisplayName, user.EmailAddress);

            context.Response.ContentType = "application/javascript";
            context.Response.Write(script);
        }

        #endregion
    }
}
