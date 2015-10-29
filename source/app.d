import std.stdio;
import std.process;
import std.getopt;
import std.parallelism;

import server;
import utils;

int main(string[] args)
{
	string token;
	debug{string dbpath = "database.db";}
	version(release){string dbpath = ":memory:";}
	bool help;
	getopt(args,
			"token|t",&token,
			"database",&dbpath,
			"help|h",&help);
	if (help)
	{
		printHelp();
		return 0;
	}
	debug
	{
		auto settings = ServerSettings(environment["bottoken"]);
	}
	version(release)
	{
		auto settings = ServerSettings(token);
	}
	settings.dbpath = dbpath;
	auto server = new Server(settings);
	auto scheduler = task!runScheduler(&server);
	scheduler.executeInNewThread();
	scheduler.yieldForce();
	return 0;
}

void runScheduler(Server* server)
{
	server.runScheduler();
}
