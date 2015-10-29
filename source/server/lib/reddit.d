module reddit;

import std.json;
import std.net.curl;
import std.exception;
import std.stdio;

struct Post
{
	string title;
	string url;
	string author;
}

Post getHot(string subreddit)
{
	string url = "https://reddit.com/r/"~subreddit~".json";
	auto rawresponse = get(url);
	JSONValue response = parseJSON(rawresponse)["data"]["children"].array[0]["data"];
	auto p = Post();
	p.title = response["title"].str;
	p.url = response["url"].str;
	p.author = response["author"].str;
	return p;
}

unittest
{
	Post p = getHot("news");
	writeln(p);
}
