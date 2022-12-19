import { dirname } from 'path';
import { exec } from 'child_process';
import { existsSync, readFileSync, renameSync, writeFileSync } from 'fs';
import { fileURLToPath } from 'url';


const __dirname = dirname(fileURLToPath(import.meta.url));
const configPath = './build.config.json';

/**
 * @param {number} x 
 * @returns {string}
 */
const numberToBase64 = (x) => x.toString(2).split(/(?=(?:.{6})+(?!.))/g).map(v=>"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"[parseInt(v,2)]).join("");


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
            JSON.stringify(
                {
                    "bin": "/path/to/godot/headless/bin",
                    "mainPreset": "Production",
                    "mainPresetPath": "./build/index.html",
                    "pckPresets": {
                        "NameOfPck": "./build/pck/name_of.pck",
                    },
                },
                null,
                "\t"
            )
        );
        return;
    }


    const config = JSON.parse(
        readFileSync(configPath, { encoding: 'utf-8', flag: 'r' })
    );
    const binPath = config['bin'];
    const pckPresets = config['pckPresets'];
    /**@type {string} */
    const mainPresetPath = config['mainPresetPath'];
    const mainPresetUpdatedPath = mainPresetPath.split('.html').join(`${numberToBase64(new Date().getTime())}.html`);


    log("Exporting main preset...");
    await execute(`${binPath} --export ${config['mainPreset']} ${mainPresetUpdatedPath}`, { cwd: __dirname });
    renameSync(mainPresetUpdatedPath, mainPresetPath);
    log("Exporting main preset done.");


    for (const preset in pckPresets) {
        log(`Exporting PCK preset '${preset}'...`);
        await execute(`${binPath} --export-pack ${preset} ${pckPresets[preset]}`, { cwd: __dirname });
        log(`Exporting PCK preset '${preset}' done.`);
    }
}))();
