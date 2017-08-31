--Default non system user is B1ADMIN
--Default SYSTEM password is Manager1
CREATE USER B1ADMIN PASSWORD Initial1;
CONNECT B1ADMIN PASSWORD Initial1;
ALTER USER B1ADMIN PASSWORD Initial0;
CONNECT SYSTEM PASSWORD Manager1;
ALTER USER B1ADMIN disable PASSWORD lifetime;
GRANT CONTENT_ADMIN TO B1ADMIN;
GRANT AFLPM_CREATOR_ERASER_EXECUTE TO B1ADMIN WITH ADMIN OPTION;
GRANT AFL__SYS_AFL_AFLPAL_EXECUTE TO B1ADMIN WITH ADMIN OPTION;
GRANT CREATE SCHEMA TO B1ADMIN WITH ADMIN OPTION;
GRANT USER ADMIN TO B1ADMIN WITH ADMIN OPTION;
GRANT ROLE ADMIN TO B1ADMIN WITH ADMIN OPTION;
GRANT CATALOG READ TO B1ADMIN WITH ADMIN OPTION;
GRANT IMPORT TO B1ADMIN;
GRANT EXPORT TO B1ADMIN;
GRANT INIFILE ADMIN TO B1ADMIN;
GRANT CREATE ANY, SELECT ON SCHEMA SYSTEM TO B1ADMIN;
GRANT EXECUTE ON AFL_WRAPPER_GENERATOR TO B1ADMIN WITH GRANT OPTION;
GRANT EXECUTE ON AFL_WRAPPER_ERASER TO B1ADMIN WITH GRANT OPTION;
GRANT SELECT, EXECUTE, DELETE ON SCHEMA _SYS_REPO TO B1ADMIN WITH GRANT OPTION;