//
//  Docs.swift
//  TravelPartner
//
//  Created by Utsav Hitendrabhai Pandya on 19/09/26.
//

// To find direct trains
//https://api.railradar.in/v1/trains/between/{from}/{to}
Name	In	Type	Required	Description
from	PATH	string	YES	Source station code (e.g. NDLS, INDB, MMCT)
to	PATH	string	YES	Destination station code (e.g. AGC, SVDK, HWH)
date	QUERY	string	NO	Filter trains by date at the from station (YYYY-MM-DD).
type	QUERY	vande-bharat | rajdhani | shatabdi | duronto | garib-rath | superfast | express | passenger | local | special	NO	Filter trains by type (e.g. vande-bharat, rajdhani, shatabdi, express, superfast, passenger, local). Omit for all.
category	QUERY	Premium | Superfast | Express | Passenger | Suburban | Special	NO	Filter trains by category (e.g. Premium, Superfast, Express, Passenger, Suburban, Special). Omit for all.
byCity	QUERY	true | false	NO	Expand search to all stations in source and destination metropolitan areas. Default: false.(default: false)
live	QUERY	true | false	NO	Enrich each train with live status at the from station. Default: false.(default: false)


// To calculate fare
//https://api.railradar.in/v1/trains/19559/fare?source=TPTY&destination=VG&journeyDate=2026-09-24&classCode=3A&quotaCode=GN
Name	In	Type	Required	Description
number	PATH	string	YES	5-digit train number (e.g. 12002, 12919, 12952)
source	QUERY	string	YES	Source/Boarding station code (e.g. MMCT)
destination	QUERY	string	YES	Destination station code (e.g. NDLS)
journeyDate	QUERY	string	YES	Journey date in YYYY-MM-DD format (aliases: date, startDate)
classCode	QUERY	1A | 2A | 3A | 3E | CC | EC | EA | FC | SL | 2S | VS | CH | SH | VC | EV	YES	Coach class code (e.g. 3A, 2A, 1A, SL, CC, 3E, 2S)
quotaCode	QUERY	GN | TQ | PT | LD | DF | FT | SS | YU | DP | HP | PH	NO	Quota code (Default: GN)(default: GN)


// To map route on map
//https://api.railradar.in/v1/trains/19559/route

// To get train detail
//https://api.railradar.in/v1/trains/19559?haltsOnly=true
/**
- This includes class type also. everything client wants to know about train.
 
 
 */
