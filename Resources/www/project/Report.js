/*
 * JS for Report generated by Appery.io
 */
Apperyio.getProjectGUID = function() {
    return 'f5d5c8c1-b216-42d8-8d96-5c4da4693185';
};

function navigateTo(outcome, useAjax) {
    Apperyio.navigateTo(outcome, useAjax);
}

function adjustContentHeight() {
    Apperyio.adjustContentHeightWithPadding();
}

function adjustContentHeightWithPadding(_page) {
    Apperyio.adjustContentHeightWithPadding(_page);
}

function setDetailContent(pageUrl) {
    Apperyio.setDetailContent(pageUrl);
}
Apperyio.AppPages = [{
    "name": "Screen2",
    "location": "Screen2.html"
}, {
    "name": "Account",
    "location": "Account.html"
}, {
    "name": "Screen4",
    "location": "Screen4.html"
}, {
    "name": "Screen3",
    "location": "Screen3.html"
}, {
    "name": "Report",
    "location": "Report.html"
}, {
    "name": "Home",
    "location": "Home.html"
}, {
    "name": "Screen1",
    "location": "Screen1.html"
}];

function Report_js() {
    /* Object & array with components "name-to-id" mapping */
    var n2id_buf = {
    };
    if ("n2id" in window && window.n2id !== undefined) {
        $.extend(n2id, n2id_buf);
    } else {
        window.n2id = n2id_buf;
    }
    /*
     * Nonvisual components
     */
    Apperyio.mappings = Apperyio.mappings || {};
    Apperyio.mappings["Report_restservice2_onsuccess_mapping_0"] = {
        "homeScreen": "Report",
        "directions": [
            {
                "from_name": "restservice2",
                "from_type": "SERVICE_RESPONSE",
                "to_name": "Report",
                "to_type": "UI",
                "mappings": [
                    {
                        "source": "$['body'][0]['occupation']",
                        "target": "$['occupartipn:text']"
                    },
                    {
                        "source": "$['body'][0]['agency_name']",
                        "target": "$['agnecy:text']"
                    }
                ]
            }
        ]
    };
    Apperyio.mappings["Report_restservice2_onbeforesend_mapping_0"] = {
        "homeScreen": "Report",
        "directions": [
            {
                "from_name": "test",
                "from_type": "LOCAL_STORAGE",
                "to_name": "restservice2",
                "to_type": "SERVICE_REQUEST",
                "to_default": {
                    "headers": {
                        "X-Appery-Database-Id": "{database_id}"
                    },
                    "parameters": {},
                    "body": null
                },
                "mappings": [
                    {
                        "source": "$",
                        "target_transformation": function(value) {
                            var whereObject = {
                                "Name": {
                                    "$regex": value,
                                    "$options": "i"
                                }
                            };
                            return JSON.stringify(whereObject);
                        },
                        "target": "$['parameters']['where']"
                    }
                ]
            }
        ]
    };
    Apperyio.datasources = Apperyio.datasources || {};
    window.restservice2 = Apperyio.datasources.restservice2 = new Apperyio.DataSource(Magnetic_users_info_query_service, {
        "onBeforeSend": function(jqXHR) {
            Apperyio.processMappingAction(Apperyio.mappings["Report_restservice2_onbeforesend_mapping_0"]);
        },
        "onComplete": function(jqXHR, textStatus) {
        },
        "onSuccess": function(data) {
            Apperyio.processMappingAction(Apperyio.mappings["Report_restservice2_onsuccess_mapping_0"]);
        },
        "onError": function(jqXHR, textStatus, errorThrown) {}
    });
    Apperyio.CurrentScreen = 'Report';
    _.chain(Apperyio.mappings)
        .filter(function(m) {
            return m.homeScreen === Apperyio.CurrentScreen;
        })
        .each(Apperyio.UIHandler.hideTemplateComponents);
    /*
     * Events and handlers
     */
    // On Load
    var Report_onLoad = function() {
        Report_elementsExtraJS();
        Report_deviceEvents();
        Report_windowEvents();
        Report_elementsEvents();
    };
    // screen window events
    function Report_windowEvents() {
        $('#Report').bind('pageshow orientationchange', function() {
            var _page = this;
            adjustContentHeightWithPadding(_page);
        });
    };
    // device events
    function Report_deviceEvents() {
        document.addEventListener("deviceready", function() {
        });
    };
    // screen elements extra js
    function Report_elementsExtraJS() {
        // screen (Report) extra code
    };
    // screen elements handler
    function Report_elementsEvents() {
        $(document).on("click", "a :input,a a,a fieldset label", function(event) {
            event.stopPropagation();
        });
        $(document).off("change", '[name="nqme_1"]').on({
            change: function(event) {
                try {
                    restservice2.execute({});
                } catch (e) {
                    console.error(e);
                    hideSpinner();
                };
            },
        }, '[name="nqme_1"]');
        $(document).off("click", '[name="mobilebutton_126"]').on({
            click: function(event) {
                if (!$(this).attr('disabled')) {
                    try {
                        restservice2.execute({});
                    } catch (e) {
                        console.error(e);
                        hideSpinner();
                    };
                }
            },
        }, '[name="mobilebutton_126"]');
    };
    $(document).off("pagebeforeshow", "#Report").on("pagebeforeshow", "#Report", function(event, ui) {
        Apperyio.CurrentScreen = "Report";
        _.chain(Apperyio.mappings)
            .filter(function(m) {
                return m.homeScreen === Apperyio.CurrentScreen;
            })
            .each(Apperyio.UIHandler.hideTemplateComponents);
    });
    Report_onLoad();
};
$(document).off("pagecreate", "#Report").on("pagecreate", "#Report", function(event, ui) {
    Apperyio.processSelectMenu($(this));
    Report_js();
});