// Roissy Calendar
string BASE_URL = "https://calendar.google.com/calendar/u/0/embed?src=roissyvaldoise@gmail.com&ctz=";
string URL_END = "&pli=1";

integer CHANNEL;
key USER;

list TIMEZONES = [
    "Africa/Abidjan","Africa/Algiers","Africa/Bissau","Africa/Cairo","Africa/Casablanca","Africa/Ceuta",
    "Africa/El_Aaiun","Africa/Johannesburg","Africa/Juba","Africa/Khartoum","Africa/Lagos","Africa/Maputo",
    "Africa/Monrovia","Africa/Nairobi","Africa/Sao_Tome","Africa/Tunis","Africa/Tripoli","Africa/Windhoek",
    "America/Adak","America/Anchorage","America/Araguaina","America/Argentina/Buenos_Aires","America/Argentina/Catamarca",
    "America/Argentina/Cordoba","America/Argentina/Jujuy","America/Argentina/La_Rioja","America/Argentina/Mendoza",
    "America/Argentina/Rio_Gallegos","America/Argentina/Salta","America/Argentina/San_Juan","America/Argentina/San_Luis",
    "America/Argentina/Tucuman","America/Asuncion","America/Bahia","America/Bahia_Banderas","America/Barbados",
    "America/Belem","America/Belize","America/Bogota","America/Boa_Vista","America/Boise","America/Cambridge_Bay",
    "America/Cancun","America/Caracas","America/Cayenne","America/Chicago","America/Chihuahua","America/Ciudad_Juarez",
    "America/Costa_Rica","America/Cuiaba","America/Danmarkshavn","America/Denver","America/Detroit","America/Dawson",
    "America/Dawson_Creek","America/Edmonton","America/Eirunepe","America/El_Salvador","America/Glace_Bay","America/Goose_Bay",
    "America/Grand_Turk","America/Guatemala","America/Guayaquil","America/Guyana","America/Halifax","America/Havana",
    "America/Hermosillo","America/Indiana/Indianapolis","America/Indiana/Knox","America/Indiana/Marengo",
    "America/Indiana/Petersburg","America/Indiana/Tell_City","America/Indiana/Vevay","America/Indiana/Vincennes",
    "America/Indiana/Winamac","America/Inuvik","America/Iqaluit","America/Jamaica","America/Juneau","America/Kentucky/Louisville",
    "America/Kentucky/Monticello","America/La_Paz","America/Lima","America/Los_Angeles","America/Maceio","America/Managua",
    "America/Manaus","America/Matamoros","America/Martinique","America/Mazatlan","America/Menominee","America/Merida",
    "America/Mexico_City","America/Miquelon","America/Moncton","America/Monterrey","America/Nome","America/Noronha",
    "America/North_Dakota/Beulah","America/North_Dakota/Center","America/North_Dakota/New_Salem","America/Nuuk",
    "America/Ojinaga","America/Panama","America/Paramaribo","America/Phoenix","America/Port-au-Prince","America/Porto_Velho",
    "America/Puerto_Rico","America/Punta_Arenas","America/Rankin_Inlet","America/Recife","America/Regina","America/Resolute",
    "America/Rio_Branco","America/Santiago","America/Santo_Domingo","America/Sao_Paulo","America/Scoresbysund","America/Sitka",
    "America/St_Johns","America/Santarem","America/Swift_Current","America/Thule","America/Tijuana","America/Toronto",
    "America/Vancouver","America/Whitehorse","America/Winnipeg","America/Yakutat",
    "Antarctica/Casey","Antarctica/Davis","Antarctica/Macquarie","Antarctica/Mawson","Antarctica/Palmer",
    "Antarctica/Rothera","Antarctica/Troll","Antarctica/Vostok",
    "Asia/Almaty","Asia/Amman","Asia/Anadyr","Asia/Aqtau","Asia/Aqtobe","Asia/Ashgabat","Asia/Atyrau",
    "Asia/Baghdad","Asia/Bangkok","Asia/Barnaul","Asia/Beirut","Asia/Bishkek","Asia/Chita","Asia/Colombo",
    "Asia/Damascus","Asia/Dhaka","Asia/Dili","Asia/Dubai","Asia/Dushanbe","Asia/Gaza","Asia/Hebron","Asia/Ho_Chi_Minh",
    "Asia/Hovd","Asia/Irkutsk","Asia/Jakarta","Asia/Jayapura","Asia/Jerusalem","Asia/Kabul","Asia/Kamchatka",
    "Asia/Karachi","Asia/Kathmandu","Asia/Khandyga","Asia/Kolkata","Asia/Krasnoyarsk","Asia/Kuching","Asia/Macau",
    "Asia/Magadan","Asia/Makassar","Asia/Manila","Asia/Novokuznetsk","Asia/Novosibirsk","Asia/Omsk","Asia/Oral",
    "Asia/Pontianak","Asia/Pyongyang","Asia/Qatar","Asia/Qostanay","Asia/Qyzylorda","Asia/Riyadh","Asia/Sakhalin",
    "Asia/Samarkand","Asia/Seoul","Asia/Shanghai","Asia/Singapore","Asia/Srednekolymsk","Asia/Taipei","Asia/Tashkent",
    "Asia/Tehran","Asia/Tbilisi","Asia/Thimphu","Asia/Tokyo","Asia/Tomsk","Asia/Ulaanbaatar","Asia/Urumqi",
    "Asia/Ust-Nera","Asia/Vladivostok","Asia/Yakutsk","Asia/Yangon","Asia/Yekaterinburg","Asia/Yerevan",
    "Atlantic/Azores","Atlantic/Bermuda","Atlantic/Cape_Verde","Atlantic/Canary","Atlantic/Faroe","Atlantic/Madeira",
    "Atlantic/South_Georgia","Atlantic/Stanley",
    "Australia/Adelaide","Australia/Brisbane","Australia/Broken_Hill","Australia/Darwin","Australia/Eucla",
    "Australia/Hobart","Australia/Lindeman","Australia/Lord_Howe","Australia/Melbourne","Australia/Perth","Australia/Sydney",
    "Europe/Andorra","Europe/Athens","Europe/Belgrade","Europe/Berlin","Europe/Bratislava","Europe/Brussels","Europe/Bucharest",
    "Europe/Budapest","Europe/Chisinau","Europe/Copenhagen","Europe/Dublin","Europe/Gibraltar","Europe/Helsinki","Europe/Istanbul",
    "Europe/Kaliningrad","Europe/Kiev","Europe/Lisbon","Europe/Ljubljana","Europe/London","Europe/Luxembourg","Europe/Madrid",
    "Europe/Malta","Europe/Monaco","Europe/Moscow","Europe/Oslo","Europe/Paris","Europe/Prague","Europe/Riga","Europe/Rome",
    "Europe/Samara","Europe/San_Marino","Europe/Sarajevo","Europe/Saratov","Europe/Simferopol","Europe/Skopje","Europe/Sofia",
    "Europe/Stockholm","Europe/Tallinn","Europe/Tirane","Europe/Ulyanovsk","Europe/Uzhgorod","Europe/Vaduz","Europe/Vatican",
    "Europe/Vienna","Europe/Vilnius","Europe/Volgograd","Europe/Warsaw","Europe/Zagreb","Europe/Zaporozhye","Europe/Zurich",
    "Pacific/Apia","Pacific/Auckland","Pacific/Chatham","Pacific/Easter","Pacific/Efate","Pacific/Enderbury","Pacific/Fakaofo",
    "Pacific/Fiji","Pacific/Funafuti","Pacific/Galapagos","Pacific/Gambier","Pacific/Guadalcanal","Pacific/Guam","Pacific/Honolulu",
    "Pacific/Johnston","Pacific/Kanton","Pacific/Kiritimati","Pacific/Kosrae","Pacific/Kwajalein","Pacific/Majuro","Pacific/Marquesas",
    "Pacific/Midway","Pacific/Nauru","Pacific/Niue","Pacific/Norfolk","Pacific/Noumea","Pacific/Pago_Pago","Pacific/Palau",
    "Pacific/Pitcairn","Pacific/Pohnpei","Pacific/Port_Moresby","Pacific/Rarotonga","Pacific/Saipan","Pacific/Tahiti",
    "Pacific/Tarawa","Pacific/Tongatapu","Pacific/Wake","Pacific/Wallis"
];

list CONTINENTS;
list MENU_MAPPING;

integer PAGE = 0;
integer PAGE_SIZE = 9;

string STATE = "READY";
string CURRENT_CONTINENT;
string CURRENT_COUNTRY;

// ======================= FUNCTIONS =======================

list getCountries(string continent)
{
    list result;
    integer i;
    for (i = 0; i < llGetListLength(TIMEZONES); i++)
    {
        list parts = llParseString2List(llList2String(TIMEZONES, i), ["/"], []);
        if (llList2String(parts, 0) == continent && llGetListLength(parts) > 1)
        {
            string country = llList2String(parts, 1);
            if (llListFindList(result, [country]) == -1)
            {
                result += [country];
            }
        }
    }
    return result;
}

list getCities(string continent, string country)
{
    list result;
    integer i;
    for (i = 0; i < llGetListLength(TIMEZONES); i++)
    {
        list parts = llParseString2List(llList2String(TIMEZONES, i), ["/"], []);
        if (llList2String(parts, 0) == continent)
        {
            if (llGetListLength(parts) == 2)
            {
                if (llList2String(parts, 1) == country)
                {
                    result += [llList2String(parts, 1)]; // 2-level timezone
                }
            }
            else if (llGetListLength(parts) >= 3)
            {
                if (llList2String(parts, 1) == country)
                {
                    result += [llList2String(parts, 2)]; // 3-level timezone
                }
            }
        }
    }
    return result;
}

list paginate(list data)
{
    integer start = PAGE * PAGE_SIZE;
    integer end = start + PAGE_SIZE - 1;
    integer maxIndex = llGetListLength(data) - 1;

    if (start > maxIndex) start = maxIndex;
    if (end > maxIndex) end = maxIndex;

    list page = llList2List(data, start, end);

    list result = [];
    integer i;

    // Add navigation buttons only if needed
    if (PAGE > 0 || end < maxIndex)
    {
        if (PAGE > 0) result += ["<< Back"]; else result += [" "];
        result += [" "]; // spacer in middle
        if (end < maxIndex) result += ["Next >>"]; else result += [" "];
    }

    // Add actual items in reverse order for top-to-bottom display
    for (i = llGetListLength(page) - 1; i >= 0; i--)
    {
        result += [llList2String(page, i)];
    }

    return result;
}

showMenu(string text, list items)
{
    CHANNEL = -1 - (integer)llFrand(1000000);
    llListen(CHANNEL, "", USER, "");
    MENU_MAPPING = items;
    llDialog(USER, text, paginate(items), CHANNEL);
}

DisplayLinkAndReset(string tz) {
    llRegionSayTo(USER, 0, "Here is your Roissy calendar link:\n" + BASE_URL + tz + URL_END + "\nRemember to bookmark it and check daily for the next cool event, workshop or discussion here at Roissy");
    STATE = "READY"; USER = NULL_KEY; PAGE = 0;
}

refresh()
{
    if (STATE == "CONTINENT")
    {
        showMenu("Choose continent:", CONTINENTS);
    }
    else if (STATE == "COUNTRY")
    {
        list countries = getCountries(CURRENT_CONTINENT);
        integer countryCount = llGetListLength(countries);

        if (countryCount == 1)
        {
            CURRENT_COUNTRY = llList2String(countries, 0);
            list cities = getCities(CURRENT_CONTINENT, CURRENT_COUNTRY);
            integer cityCount = llGetListLength(cities);

            if (cityCount <= 1)
            {
                string tz = CURRENT_CONTINENT + "/" + CURRENT_COUNTRY;
                DisplayLinkAndReset(tz);
            }
            else
            {
                STATE = "CITY"; PAGE = 0;
                showMenu("Choose city for " + CURRENT_COUNTRY + ":", cities);
            }
        }
        else
        {
            string label;
            if (CURRENT_CONTINENT == "America" || CURRENT_CONTINENT == "Australia")
            {
                label = "Choose state/territory for " + CURRENT_CONTINENT + ":";
            }
            else
            {
                label = "Choose country for " + CURRENT_CONTINENT + ":";
            }
            showMenu(label, countries);
        }
    }
    else if (STATE == "CITY")
    {
        list cities = getCities(CURRENT_CONTINENT, CURRENT_COUNTRY);
        showMenu("Choose city for " + CURRENT_COUNTRY + ":", cities);
    }
}

// ======================= DEFAULT STATE =======================

default
{
    state_entry()
    {
        integer i;
        for (i = 0; i < llGetListLength(TIMEZONES); i++)
        {
            list parts = llParseString2List(llList2String(TIMEZONES, i), ["/"], []);
            string cont = llList2String(parts, 0);
            if (llListFindList(CONTINENTS, [cont]) == -1)
            {
                CONTINENTS += [cont];
            }
        }
        llOwnerSay("Ready! Touch to choose your Roissy calendar.");
    }

    touch_start(integer total_number)
    {
        USER = llDetectedKey(0);
        STATE = "CONTINENT"; PAGE = 0;
        refresh();
    }

    listen(integer channel, string name, key id, string message)
    {
        integer idx = llListFindList(MENU_MAPPING, [message]);
        string fullMessage;
        if (idx != -1)
        {
            fullMessage = llList2String(MENU_MAPPING, idx);
        }
        else
        {
            fullMessage = message;
        }

        // Handle pagination
        if (fullMessage == "Next >>") { PAGE++; refresh(); return; }
        if (fullMessage == "<< Back") { PAGE--; refresh(); return; }
        if (fullMessage == " ") { refresh(); return; }

        if (STATE == "CONTINENT")
        {
            CURRENT_CONTINENT = fullMessage;
            list countries = getCountries(CURRENT_CONTINENT);
            if (llGetListLength(countries) == 0)
            {
                list cities = getCities(CURRENT_CONTINENT, "");
                if (llGetListLength(cities) > 0)
                {
                    string tz = CURRENT_CONTINENT + "/" + llList2String(cities, 0);
                    DisplayLinkAndReset(tz);
                }
            }
            else
            {
                STATE = "COUNTRY"; PAGE = 0;
            }
        }
        else if (STATE == "COUNTRY")
        {
            CURRENT_COUNTRY = fullMessage;
            list cities = getCities(CURRENT_CONTINENT, CURRENT_COUNTRY);
            if (llGetListLength(cities) <= 1)
            {
                string tz = CURRENT_CONTINENT + "/" + CURRENT_COUNTRY;
                DisplayLinkAndReset(tz);
            }
            else
            {
                STATE = "CITY"; PAGE = 0;
            }
        }
        else if (STATE == "CITY")
        {
            string tz = CURRENT_CONTINENT + "/" + CURRENT_COUNTRY + "/" + fullMessage;
            DisplayLinkAndReset(tz);
        }

        refresh();
    }
}