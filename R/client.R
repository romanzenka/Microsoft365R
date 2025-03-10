#' Login clients for Microsoft 365
#'
#' Microsoft365R provides functions for logging into each Microsoft 365 service.
#'
#' @param tenant For `get_business_onedrive`, `get_sharepoint_site` and `get_team`, the name of your Azure Active Directory (AAD) tenant. If not supplied, use the value of the `CLIMICROSOFT365_TENANT` environment variable, or "common" if that is unset.
#' @param app A custom app registration ID to use for authentication. See below.
#' @param scopes The Microsoft Graph scopes (permissions) to obtain. It should never be necessary to change these.
#' @param site_name,site_url,site_id For `get_sharepoint_site`, either the name, web URL or ID of the SharePoint site to retrieve. Supply exactly one of these.
#' @param team_name,team_id For `get_team`, either the name or ID of the team to retrieve. Supply exactly one of these.
#' @param ... Optional arguments that will ultimately be passed to [`AzureAuth::get_azure_token`].
#' @details
#' These functions provide easy access to the various collaboration services that are part of Microsoft 365. On first use, they will call your web browser to authenticate with Azure Active Directory, in a similar manner to other web apps. You will get a dialog box asking for permission to access your information. You only have to authenticate once; your credentials will be saved and reloaded in subsequent sessions.
#'
#' When authenticating, you can pass optional arguments in `...` which will ultimately be received by `AzureAuth::get_azure_token`. In particular, if your machine doesn't have a web browser available to authenticate with (for example if you are in a remote RStudio Server session), pass `auth_type="device_code"` which is intended for such scenarios.
#'
#' @section Authenticating to Microsoft 365 Business services:
#' Authenticating to Microsoft 365 Business services (Teams, SharePoint and OneDrive for Business) has some specific complexities.
#'
#' The default "common" tenant for `get_team`, `get_business_onedrive` and `get_sharepoint_site` attempts to detect your actual tenant from your saved credentials in your browser. This may not always succeed, for example if you have a personal account that is also a guest account in a tenant. In this case, supply the actual tenant name, either in the `tenant` argument or in the `CLIMICROSOFT365_TENANT` environment variable. The latter allows sharing authentication details with the [CLI for Microsoft 365](https://pnp.github.io/cli-microsoft365/).
#'
#' The default when authenticating to these services is for Microsoft365R to use its own internal app ID. As an alternative, you (or your admin) can create your own app registration in Azure: it should have a native redirect URI of `http://localhost:1410`, and the "public client" option should be enabled if you want to use the device code authentication flow. You can supply your app ID either via the `app` argument, or in the environment variable `CLIMICROSOFT365_AADAPPID`.
#'
#' @return
#' For `get_personal_onedrive` and `get_business_onedrive`, an R6 object of class `ms_drive`.
#'
#' For `get_sharepoint_site`, an R6 object of class `ms_site`; for `list_sharepoint_sites`, a list of such objects.
#'
#' For `get_team`, an R6 object of class `ms_team`; for `list_teams`, a list of such objects.
#' @seealso
#' [`ms_drive`], [`ms_site`], [`ms_team`]
#'
#' [`add_methods`] for the associated methods that this package adds to the base AzureGraph classes.
#'
#' The "Authentication" vignette has more details on the authentication process, including troubleshooting and fixes for common problems.
#'
#' [CLI for Microsoft 365](https://pnp.github.io/cli-microsoft365/) -- a commandline tool for managing Microsoft 365
#' @examples
#' \dontrun{
#'
#' get_personal_onedrive()
#'
#' # authenticating without a browser
#' get_personal_onedrive(auth_type="device_code")
#'
#' odb <- get_business_onedrive("mycompany")
#' odb$list_items()
#'
#' mysite <- get_sharepoint_site("My site", tenant="mycompany")
#' mysite <- get_sharepoint_site(site_url="https://mycompany.sharepoint.com/sites/my-site-url")
#' mysite$get_drive()$list_items()
#'
#' myteam <- get_team("My team", tenant="mycompany")
#' myteam$list_channels()
#' myteam$get_drive()$list_items()
#'
#' # you can also use your own app registration ID:
#' get_business_onedrive(app="app_id")
#' get_sharepoint_site("My site", app="app_id")
#'
#' # using the app ID for the CLI for Microsoft 365: set a global option
#' options(microsoft365r_use_cli_app_id=TRUE)
#' get_business_onedrive()
#' get_sharepoint_site("My site")
#' get_team("My team")
#'
#' }
#' @rdname client
#' @export
get_personal_onedrive <- function(app=.microsoft365r_app_id,
                                  scopes=c("Files.ReadWrite.All", "User.Read"),
                                  ...)
{
    do_login("consumers", app, scopes, ...)$get_user()$get_drive()
}

#' @rdname client
#' @export
get_business_onedrive <- function(tenant=Sys.getenv("CLIMICROSOFT365_TENANT", "common"),
                                  app=Sys.getenv("CLIMICROSOFT365_AADAPPID"),
                                  scopes=".default",
                                  ...)
{
    app <- choose_app(app)
    do_login(tenant, app, scopes, ...)$get_user()$get_drive()
}

#' @rdname client
#' @export
get_sharepoint_site <- function(site_name=NULL, site_url=NULL, site_id=NULL,
                                tenant=Sys.getenv("CLIMICROSOFT365_TENANT", "common"),
                                app=Sys.getenv("CLIMICROSOFT365_AADAPPID"),
                                scopes=".default",
                                ...)
{
    assert_one_arg(site_name, site_url, site_id, msg="Supply exactly one of site name, URL or ID")
    app <- choose_app(app)
    login <- do_login(tenant, app, scopes, ...)

    if(!is.null(site_name))
    {
        filter <- sprintf("displayName eq '%s'", site_name)
        mysites <- login$get_user()$list_sharepoint_sites(filter=filter)
        if(length(mysites) == 0)
            stop("Site '", site_name, "' not found", call.=FALSE)
        else if(length(mysites) > 1)
            stop("Site name '", site_name, "' is not unique", call.=FALSE)
        mysites[[1]]
    }
    else login$get_sharepoint_site(site_url, site_id)
}

#' @rdname client
#' @export
list_sharepoint_sites <- function(tenant=Sys.getenv("CLIMICROSOFT365_TENANT", "common"),
                                  app=Sys.getenv("CLIMICROSOFT365_AADAPPID"),
                                  scopes=".default",
                                  ...)
{
    app <- choose_app(app)
    login <- do_login(tenant, app, scopes, ...)

    login$get_user()$list_sharepoint_sites()
}

#' @rdname client
#' @export
get_team <- function(team_name=NULL, team_id=NULL,
                     tenant=Sys.getenv("CLIMICROSOFT365_TENANT", "common"),
                     app=Sys.getenv("CLIMICROSOFT365_AADAPPID"),
                     scopes=".default",
                     ...)
{
    assert_one_arg(team_name, team_id, msg="Supply exactly one of team name or ID")
    app <- choose_app(app)
    login <- do_login(tenant, app, scopes, ...)

    if(!is.null(team_name))
    {
        filter <- sprintf("displayName eq '%s'", team_name)
        myteams <- login$get_user()$list_teams(filter=filter)
        if(length(myteams) == 0)
            stop("Team '", team_name, "' not found", call.=FALSE)
        else if(length(myteams) > 1)
            stop("Team name '", team_name, "' is not unique", call.=FALSE)
        myteams[[1]]
    }
    else login$get_team(team_id)
}

#' @rdname client
#' @export
list_teams <- function(tenant=Sys.getenv("CLIMICROSOFT365_TENANT", "common"),
                       app=Sys.getenv("CLIMICROSOFT365_AADAPPID"),
                       scopes=".default",
                       ...)
{
    app <- choose_app(app)
    login <- do_login(tenant, app, scopes, ...)

    login$get_user()$list_teams()
}


.ms365_login_env <- new.env()

do_login <- function(tenant, app, scopes, ...)
{
    hash <- function(...)
    {
        as.character(openssl::md5(serialize(list(...), NULL)))
    }

    login_id <- hash(tenant, app, scopes, ...)
    login <- .ms365_login_env[[login_id]]
    if(is.null(login) || !inherits(login, "ms_graph"))
    {
        login <- try(get_graph_login(tenant, app=app, scopes=scopes, refresh=FALSE), silent=TRUE)
        if(inherits(login, "try-error"))
            login <- create_graph_login(tenant, app=app, scopes=scopes, ...)
        .ms365_login_env[[login_id]] <- login
    }
    login
}


choose_app <- function(app)
{
    if(is.null(app) || app == "")
    {
        if(!is.null(getOption("microsoft365r_use_cli_app_id")))
            .cli_microsoft365_app_id
        else .microsoft365r_app_id
    }
    else app
}


assert_one_arg <- function(..., msg=NULL)
{
    arglst <- list(...)
    nulls <- sapply(arglst, is.null)
    if(sum(!nulls) != 1)
        stop(msg, call.=FALSE)
}
