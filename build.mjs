import { dirname } from 'path';
import { exec } from 'child_process';
import { existsSync, readFileSync, writeFileSync } from 'fs';
import { fileURLToPath } from 'url';


const __dirname = dirname(fileURLToPath(import.meta.url));
const configPath = './build.config.json';


/**
 * @param {string} cmd 
 * @param {import('child_process').ExecOptions} options 
 * @returns {Promise<{stdout:string,stderr:string}>}
 */
const execute = (cmd, options) => {
    return new Promise((resolve, reject) => {
        exec(cmd, options, (error, stdout, stderr) => {
            if (error) {
                return reject(error);
            }
            resolve({
                'stdout': stdout,
                'stderr': stderr,
            });
        });
    });
};


/**
 * @param {string} msg 
 */
const log = (msg) => {
    console.log(`[${new Date().toUTCString()}] ${msg}`);
};


((async () => {
    if (!existsSync(configPath)) {
        writeFileSync(
            configPath,
            JSON.stringify({
                "bin": "/path/to/godot/headless/bin",
                "buildNumberPath": "./build.number.txt",
                "mainPreset": "Production",
                "mainPresetPath": "./build/index.html",
                "pckPresets": {
                    "NameOfPck": "./build/pck/name_of.pck",
                },
            })
        );
        return;
    }

    const config = JSON.parse(
        readFileSync(configPath, { encoding: 'utf-8', flag: 'r' })
    );
    const binPath = config['bin'];
    const pckPresets = config['pckPresets'];
    const buildNumberPath = config['buildNumberPath'];


    if (!existsSync(buildNumberPath)) {
        writeFileSync(buildNumberPath, "0\n");
        log(`Generated new build number indicator file at '${buildNumberPath}'.`);
    } else {
        /** @type {number} */
        writeFileSync(
            buildNumberPath,
            JSON.stringify(JSON.parse(readFileSync(buildNumberPath, { encoding: 'utf8' })) + 1)
        );
        log(`Updated build number indicator.`)
    }


    log("Exporting main preset...");
    await execute(`${binPath} --export ${config['mainPreset']} ${config['mainPresetPath']}`, { cwd: __dirname });
    log("Exporting main preset done.");


    for (const preset in pckPresets) {
        log(`Exporting PCK preset '${preset}'...`);
        await execute(`${binPath} --export-pack ${preset} ${pckPresets[preset]}`, { cwd: __dirname });
        log(`Exporting PCK preset '${preset}' done.`);
    }
}))();
