using System;
using System.Collections.Generic;
using System.DirectoryServices.AccountManagement;
using System.Linq;
using System.Web;

namespace SAP.BusinessOne.Web
{
    class DomainUser
    {
        private static readonly PrincipalContext domain = new PrincipalContext(ContextType.Domain);

        public DomainUser(string alias)
        {
            using (UserPrincipal user = UserPrincipal.FindByIdentity(domain, alias))
            {
                EmailAddress = user.EmailAddress;
                EmployeeId = alias.Split('\\')[1].ToLower();
                GivenName = user.GivenName;
                MiddleName = user.MiddleName;
                Surname = user.Surname;
            }
        }

        public string EmailAddress { get; private set; }
        public string EmployeeId { get; private set; }
        public string GivenName { get; private set; }
        public string MiddleName { get; private set; }
        public string Surname { get; private set; }
        public string DisplayName
        {
            get
            {
                return GivenName + " " + Surname;
            }
        }

        public override string ToString()
        {
            return string.Format("{0} ({1})", DisplayName, EmployeeId);
        }
    }
}