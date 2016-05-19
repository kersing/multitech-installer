// Node-JS program to merge TheThingsNetwork configuration with changes required
// for MultiTech LoRaWAN gateway.
//
// Copyright by Jac Kersing <j.kersing@the-box.com>
//
//  Use of this source code is governed by the MIT license that can be found in the LICENSE file
//  at github.com/kersing/multitech-installer
//
function substitute(path, prop, value) {
	var element = 'ttnjson'
	for (var i = 0; i < path.length; i++) {
		element = element + "." + path[i];
	}
	element = element+"."+prop;
	if (typeof(value) == "string") {
		eval(element + "=\"" + value +"\"");
	} else {
		eval(element + "=" + value);
	}
}	

function substproperties(node, path) {
    if (node instanceof Array) {
        for (var i=0; i<node.length; i++) {
            if (typeof node[i] == "object" && node[i]) {
		path.push(prop);
                substproperties(node[prop],path);
		path.pop();
            } else {
		substitute(path, prop, node[prop]);
            }
        }
    } else {
        for (var prop in node) {
            if (typeof node[prop] == "object" && node[prop]) {
		path.push(prop);
                substproperties(node[prop],path);
		path.pop();
            } else {
		substitute(path, prop, node[prop]);
            }
        }
    }
}

ttncfgname='/var/config/lora/ttn_global_conf.json';
overridesname='/var/config/lora/multitech_overrides.json';
outputname='/var/config/lora/global_conf.json';
if (process.argv.length > 2) {
	if (process.argv[2] == '-h' || process.argv[2] == '--help') {
		console.log('Usage: node merge.js [ttn global_conf.json] [multitech_overrides.json] [output global_conf.json]');
		process.exit(0);
	}
	ttncfgname = process.argv[2];
	if (process.argv.length > 3) {
		overridesname=process.argv[3];
		if (process.argv.length > 4) {
			outputname=process.argv[4];
		}
	}
}

var fs = require('fs');
ttnconfig = fs.readFileSync(ttncfgname, 'utf8');
config = ttnconfig;

// skip all comments in the input global_conf.json file
found=config.indexOf("/*");
while (found != -1) {
	endpos = config.indexOf("*/");
	if (endpos != -1) {
		config = config.substring(0,found) + config.substring(endpos+2);
	}
	found=config.indexOf("/*");
}

ttnjson = JSON.parse(config);
start=overridesname.substring(0,1);
if (start != '.' && start != '/') {
	overridesname = './' + overridesname;
}
mtoverrides = require(overridesname);
substproperties(mtoverrides, new Array());
fs.writeFile(outputname, JSON.stringify(ttnjson,null,4));
