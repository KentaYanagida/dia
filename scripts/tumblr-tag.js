/**
 * Description:
 *   TumblrのPhoto投稿からランダムで返却
 *
 * Commands:
 *   (free word)の<絵|イラスト>
 */

const request = require('request');

const uri = 'https://api.tumblr.com/v2/tagged';
const limit = 5;

module.exports = robot => {
    robot.respond(/(.+)の(絵|イラスト)/i, msg => {
        const query = msg.match[1];
        const apiKey = "O0zjjGR8YTA0VEXSr9TY2L0PXCxlIdASbCSQLHNTc8Kk2ymCU0";

        const requestUrl = uri + '?tag=' + query + '&limit=' + limit + '&api_key=' + apiKey;
        request(requestUrl, (err, response, body) => {
            if (err) {
                console.log(err);
                msg.send('失敗しましたわ･･･。');
                return;
            }
            
            const arrayContents = JSON.parse(body);
            if (arrayContents.response.length < 1) {
                msg.send('見つかりませんでしたわ。');
                return;
            }

            // 画像コンテンツの投稿URLだけリスト化
            let photoPostList = [];
            for (let content of arrayContents.response) {
                if (content.type === "photo") {
                    photoPostList.push(content.post_url);
                }
            }

            msg.send(msg.random(photoPostList));
        });

    });
};
