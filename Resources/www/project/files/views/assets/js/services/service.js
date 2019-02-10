/*
 * Security contexts
 */
/*
 * Service settings
 */
var Magnetic_settings = {
    "database_id": "5c5faddb0f0d31350a6b65fb"
}
/*
 * Services
 */
var Magnetic_users_info_query_service = new Apperyio.RestService({
    'url': 'https://api.appery.io/rest/1/db/collections/users_info',
    'dataType': 'json',
    'type': 'get',
    'serviceSettings': Magnetic_settings
        ,
    'defaultRequest': {
        "headers": {
            "X-Appery-Database-Id": "{database_id}"
        },
        "parameters": {},
        "body": null
    }
});
var Magnetic_Report_create_service = new Apperyio.RestService({
    'url': 'https://api.appery.io/rest/1/db/collections/Report',
    'dataType': 'json',
    'type': 'post',
    'contentType': 'application/json',
    'serviceSettings': Magnetic_settings
        ,
    'defaultRequest': {
        "headers": {
            "X-Appery-Database-Id": "{database_id}",
            "Content-Type": "application/json"
        },
        "parameters": {},
        "body": {
            "acl": {
                "*": {
                    "write": true,
                    "read": true
                }
            }
        }
    }
});