module server;

import std.datetime;
import std.conv;
import std.algorithm.iteration;
import std.stdio;
import std.string;
import std.parallelism;
import core.thread;
import core.exception;

import delegram;
import update;
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

	public void runInterface()
	{
		while (true)
		{
			auto updates = bot.getUpdates();
			foreach (update;parallel(updates))
			{
				processUpdate(update);
			}
			Thread.sleep(dur!("seconds")(1));
		}
	}

	private void processUpdate(Update update)
	{
		auto command = update.message.text.split(" ");
		switch (command[0])
		{
			case "/start":
				bot.sendMessage(update.message.chat.id,"Welcome to the goodmorning Bot!\n"~
								"Available Commands:\n"~
								"/settime <hour> <minute> <offset> - Sets the time for the news Message\n"~
								"/setsub <subreddit> Sets the source subreddit (Default: /r/news)\n"~
								"/help - Prints this text");
				break;
			case "/help":
				goto case "/start";
			case "/settime":
				int hour;
				int minute;
				int offset;
				try
				{
					hour = to!int(command[1]);
					offset = to!int(command[3]);
					minute = to!int(command[2]);
				}
				catch (RangeError ex)
				{
					bot.sendMessage(update.message.chat.id,"Invalid Syntax");
					break;
				}
				catch (Exception ex)
				{
					bot.sendMessage(update.message.chat.id,"Invalid Syntax");
					break;
				}

				if (hour >= 24 || minute >= 60 || hour < 0 || minute < 0 || offset > 11 || offset < -11)
				{
					bot.sendMessage(update.message.chat.id,"Please enter valid data");
					break;
				}

				// Converting to UTC
				if (hour - offset < 0)
					hour = 24 - hour - offset;
				else if (hour - offset >= 24)
					hour = hour - offset - 24;
				else
					hour = hour - offset;

				if (database.execute("SELECT count(*) FROM users WHERE id="~to!string(update.message.chat.id))
						.oneValue!long == 0)
				{
					auto statement = database.prepare("INSERT INTO users (id,sub,hour,minute) VALUES(
						:id,:sub,:hour,:minute)");
					statement.bindAll(update.message.chat.id,"news",hour,minute);
					statement.execute();
				}
				else
				{
					auto statement = database.prepare("UPDATE users SET hour=:hour,minute=:minute WHERE id = :id");
					statement.bindAll(hour,minute,update.message.chat.id);
					statement.execute();
				}
				bot.sendMessage(update.message.chat.id,"Success!");
				break;
			case "/setsub":
				// Syntax checks
				if (command.length == 1)
				{
					bot.sendMessage(update.message.chat.id,"Invalid Syntax");
					break;
				}
				if (!subExists(command[1]))
				{
					bot.sendMessage(update.message.chat.id,"Subreddit does not exist");
					break;
				}

				// Check if the user is registered
				if (database.execute("SELECT count(*) FROM users WHERE id="~to!string(update.message.chat.id))
						.oneValue!long == 0)
					bot.sendMessage(update.message.chat.id,"Please set a time first");

				// Update the DB record
				auto statement = database.prepare("UPDATE users SET sub=:subreddit WHERE id = :id");
				statement.bindAll(command[1],update.message.chat.id);
				statement.execute();

				bot.sendMessage(update.message.chat.id,"Success!");
				break;
			default:
				bot.sendMessage(update.message.chat.id,"Invalid Command");
				break;
		}
	}

	private NewsRequest[] getRequests()
	{
		NewsRequest[] requests;
		auto time = Clock.currTime.toUTC;
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
