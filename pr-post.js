/**
 * Author - Henry Black https://github.com/blackhaj
 */

const raw = process.argv[2];

const data = JSON.parse(raw);

const title = data.title;
const body = data.body;
const fileChanges = data.files?.length;
const comments = data.comments;
const url = data.url;

// Stolen from: https://stackoverflow.com/a/6041965
// These feel very brittle 😱
const linearRegex =
  /(http|ftp|https):\/\/(linear\.app)([\w.,@?^=%&:\/~+#-]*[\w@?^=%&\/~+#-])/;
const loomRegex =
  /(http|ftp|https):\/\/(www\.loom\.com)([\w.,@?^=%&:\/~+#-]*[\w@?^=%&\/~+#-])/;

const findLinearUrl = (comments) => {
  const comment = comments.find((comment) => {
    return comment.author.login === "linear";
  });

  if (!comment) {
    return false;
  }

  const matches = comment.body.match(linearRegex);

  return matches[0];
};

const linearUrl = findLinearUrl(comments);

const findLoomUrl = (body) => {
  const matches = body.match(loomRegex);

  if (matches) {
    return matches[0];
  }
  return false;
};

const loomUrl = findLoomUrl(body);

const formattedMessage = `
*Review Request*

:male-construction-worker::skin-tone-3: ${title}
:github: PR (${fileChanges} file${fileChanges > 1 ? "s" : ""} changed) - ${url}
${linearUrl ? `:linear: Ticket - ${linearUrl}` : ""}
${loomUrl ? `:loom: Loom - ${loomUrl}` : ""}
`;

process.stdout.write(formattedMessage.trim());
