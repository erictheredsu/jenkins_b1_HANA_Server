(function (idpHost) {

    function require(module) {
        var ss = document.createElement("script");
        ss.setAttribute("type", "text/javascript");
        ss.setAttribute("src", module);
        document.getElementsByTagName("head")[0].appendChild(ss);
    }

    jQuery(document).ready(function ($) {

        var fillIdentity = null,
            applicant = $("form[name='parameters'] input[value='APPLICANT_NAME']"),
            email = $("form[name='parameters'] input[value='APPLICANT_EMAIL']");

        fillIdentity = function (_applicant, _email) {
            if (window.console) {
                console.log("fill in current user: " + _email);
            }
            applicant.next().val(_applicant);
            email.next().val(_email);
        };

        if (email.size()) {
            // hide applicant & email
            applicant.parent().parent().parent().hide();
            email.parent().parent().parent().hide();
            // expose
            window._fillIdentity = fillIdentity;
            // load external id
            require(idpHost + "/identity.js?_fillIdentity");
        }
    });

}("http://10.58.82.184:8085"));
