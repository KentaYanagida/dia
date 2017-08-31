/**
 * Description:
 *   pixivイメージ検索スクレイピング
 * 
 * Commands:
 *   dia <かわいい|カワイイ|可愛い>(free word)
 */
const phantom = require('phantom');
const cheerio = require('cheerio');

// Phantom settings
const waitTimeMsec = 10000;
const ua = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1500.71 Safari/537.36';

// Serach settings
const searchUrl = 'https://www.pixiv.net/search.php?word=';
const responseBaseUrl = 'http://embed.pixiv.net/decorate.php?illust_id=';
const addQualitySuffix = true;

// スクレイピング処理
const scraper = (msg, query) => {
    let _ph;
    let _page;

    phantom.create().then(ph => {
        _ph = ph;
        return _ph.createPage();
    }).then(page => {
        _page = page;

        // warn: Using page.settings = ...; is not supported. Use page.property('settings', ...) instead. See the README file for more examples of page#property.
        _page.settings = {
            userAgent: ua
        };

        // url
        let url = searchUrl + encodeURI(query);
        if (addQualitySuffix === true) {
            // 検索クエリにお気に入りユーザ数が多いことを示すタグを追記して検索する
            url += encodeURI(' 100user');
        }

        // send progress
        msg.send(query + 'を探していますわ..');

        return _page.open(url);
    }).then(status => {
        // console log setup
        _page.property('onConsoleMessage', function (msg) {
            console.log('console: ', msg);
        });

        // site open status logging
        console.log('Opened url?: ', status);

        // timeout promise
        const timeoutTimer = function () {
            return new Promise(function (resolve, reject) {
                setTimeout(function () {
                    reject(new Error('Page load timeouted. Wait time = ' + waitTimeMsec + 'ms.'));
                }, waitTimeMsec);
            }).catch(function(e) {
                reject(e);
            });
        }

        // scraping loop promise
        const selectorFetchLoop = function () {
            return new Promise(function (resolve, reject) {
                let dataItems = [];

                // 取得できるまでループ
                while (dataItems.length < 1) {
                    dataItems = _page.evaluate(function () {
                        return document.querySelector('html').innerHTML;
                    }).then(function (html) {
                        const $ = cheerio.load(html);
                        return $('#js-mount-point-search-result-list').attr('data-items');
                    }).catch(function(e) {
                        console.log('Failure selecting.', e);
                    });

                    console.log(dataItems);
                }

                resolve(dataItems);
            });
        };

        // 実行: タイムアウトタイマーとスクレイピングを並行処理
        Promise.race([
            timeoutTimer(),
            selectorFetchLoop()
        ]).then(function (dataItems) {
            try {
                resultJson = JSON.parse(dataItems);
            } catch (e) {
                reject(new Error('Invalid json.'));
            }

            const links = [];
            for (let key in resultJson) {
                const url = responseBaseUrl + resultJson[key]['illustId']
                links.push(url);
            }

            console.log(links);

            _page.close();
            _ph.exit();

            if (links.length > 0) {
                msg.send('これですわ！\n' + msg.random(links));
            } else {
                msg.send('見つかりませんでしたわ･･･。');
            }

            resolve();
        }).catch(function (e) {
            reject(e);
        });
    }).catch(e => {
        msg.send('検索に失敗しましたわ･･･。\n```' + e + '```')
    });
};

module.exports = robot => {
    robot.respond(/(かわいい|カワイイ|可愛い)(.+)/i, msg => {
        const query = msg.match[2];

        // メイン処理
        scraper(msg, query);
    });
};

