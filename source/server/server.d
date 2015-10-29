module server; 

import std.datetime;
import std.conv;
import std.algorithm.iteration;
import std.stdio;
import std.string;
import std.parallelism;
import core.thread;

import delegram;
import d2sqlite3;

import newsrequest;
import reddit;

class Server
{
	private Bot bot;
	private Database database;

	this(ServerSettings settings)
	{
		bot = new Bot(settings.token);
		database = Database(settings.dbpath);

		database.execute(
				"CREATE TABLE IF NOT EXISTS users(
					id INTEGER PRIMARY KEY,
					name TEXT NOT NULL,
					sub TEXT NOT NULL,
					hour TINYINT NOT NULL,
					minute TINYINT NOT NULL
				)"
		);
	}

	public void runScheduler()
	{
		// 61 to be sure that we don't skip a minute
		int offset = 61 - Clock.currTime.second;
		Thread.sleep(dur!("seconds")(offset));
		bool running = true;
		while (running)
		{
			NewsRequest[] requests = getRequests();
			writeln(requests);
			auto sendtask = task(&sendNews,requests);
			sendtask.executeInNewThread();
			Thread.sleep(dur!("seconds")(60));
		}
	}

	private NewsRequest[] getRequests()
	{
		NewsRequest[] requests;
		auto time = Clock.currTime;
		string statement = "SELECT * FROM users WHERE hour="~ to!string(time.hour) ~
			" AND minute =" ~ to!string(time.minute);
		auto results = database.execute(statement);
		foreach (row;results)
		{
			auto id = row["id"].as!uint;
			auto sub = row["sub"].as!string;
			requests ~= NewsRequest(id,sub);
		}
		return requests;
	}

	void sendNews(NewsRequest[] requests)
	{
		foreach (request;parallel(requests))
		{
			auto p = getHot(request.subreddit);
			bot.sendMessage(request.chatid,"Your news from: /r/"~request.subreddit~"\n"~
					p.title ~ ": "~p.url ~ " - /u/"~p.author);
		}
	}

}

struct ServerSettings
{
	string token;
	string dbpath;
}
