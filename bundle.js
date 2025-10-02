const fs = require("fs")
const fsp = require("fs/promises")
const cp = require("child_process")
const path = require("path")

/**
 * first part: comment
 * second part: multiline comment / multiline string
 * third part: string (with leading require)
 *
 * 1: the equal signs in multiline comment / string
 * 2: the quotation mark
 * 3: the string content
 */
const patt = /(?:--(?!\[=*\[)).*|(?:--)?\[(=*)\[[^]*?\]\1\]|(?:require\(?)?(['"])((?:\\?.)*?)\2/g

/** @type {Record<string, string|boolean>} */
const moduleBundles = {
    'imm.config': ''
}
/** @type {Record<string, Buffer>} */
const assetBundles = {}
/** @type {Record<string, Buffer>} */
const includeBundles = {}

/** @param {string} name */
async function processModule(name) {
    if (moduleBundles[name] !== undefined) return
    moduleBundles[name] = true

    const path = name.replace(/\./g, '/') + '.lua'
    const content = await fsp.readFile(path, 'utf-8')
    moduleBundles[name] = content

    const queues = []
    for (const { 0: m, 3: str } of content.matchAll(patt)) {
        if (m.startsWith('require') && str.startsWith("imm.")) {
            queues.push(processModule(str))
        }
    }

    await Promise.all(queues)
}

/**
 * @param {Record<string, Buffer>} list
 * @param {string} dir
 */
async function bundleRes(list, dir) {
    const items = await fsp.readdir(dir)
    const queues = []
    for (const file of items) {
        const subpath = dir + '/' + file
        queues.push(fsp.readFile(subpath).then(data => list[path.parse(file).name] = data))
    }
    await Promise.all(queues)
}

const prepend = `
if __IMM_B_INIT then error("Recursive load") end
__IMM_B_INIT = true
__IMM_BUNDLE = true

if not _imm then
    print("imm is loaded from bundle")
    __IMM_WRAP = true
-- packages
`

const loaderInject = `
love.filesystem.setIdentity(love.filesystem.getIdentity(), true)
local content = love.filesystem.read("main.lua")
love.filesystem.setIdentity(love.filesystem.getIdentity(), false)
local func, err = assert(loadstring(content, "@wrapped_main.lua"))
`

const append = `
-- packages
    __IMM_WRAP = true
    require("imm.main")
else
    print("imm is loaded from lovely - ignoring the bundle")
    ${loaderInject}
    assert(func, err)()
end
`

async function main() {
    const [httpsThreadCode, loaderCode] = await Promise.all([
        fsp.readFile('imm/https_thread.lua'),
        fsp.readFile('early_error.lua', 'ascii'),
        processModule('main'),
        processModule('imm.init'),
        bundleRes(assetBundles, 'assets'),
        bundleRes(includeBundles, 'include')
    ])

    const mainInjects = [
        `_imm.resbundle = { assets = {} }`,
        `_imm.resbundle.https_thread = love.filesystem.newFileData([[${httpsThreadCode}]], "(bundle)imm/https_thread.lua")`
    ]
    for (const [k, v] of Object.entries(assetBundles)) {
        mainInjects.push(`_imm.resbundle.assets[${JSON.stringify(k)}] = love.data.decode("data", "base64", "${v.toString('base64')}")`)
    }

    moduleBundles['imm.main'] = ''
        + moduleBundles.main.replace('--bundle inject', mainInjects.join('\n'))
        + loaderCode.replace('--bundle inject', loaderInject)

    delete moduleBundles['main']

    //const compiler = cp.spawn('luajit', ['-b', '-', '-'], { stdio: ['pipe', 'pipe', 'inherit'] })
    //const ostream = fs.createWriteStream('bundle.lua')
    //compiler.stdout.pipe(ostream)
    //const w = compiler.stdin

    const w = fs.createWriteStream('bundle.lua')

    w.write(prepend)

    for (const [k, v] of Object.entries(includeBundles)) {
        w.write(`package.preload["imm-"..${JSON.stringify(k)}] = function()\n${v}\nend\n`)
    }
    for (const [k, v] of Object.entries(moduleBundles)) {
        w.write(`package.preload[${JSON.stringify(k)}] = function()\n${v}\nend\n`)
    }

    w.write(append)

    w.end()
}
main()