import std.stdio;
import std.process;
import std.getopt;
import std.parallelism;

import server;
import utils;

int main(string[] args)
{
	string token;
	string dbpath = ":memory:";
	debug{dbpath = "database.db";}
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

	if (token is null)
	{
		writeln("Error: No token specified");
		return 1;
	}	
	auto settings = ServerSettings(token);
	debug{ settings.token = environment["bottoken"];}
	settings.dbpath = dbpath;
	auto server = new Server(settings);

	auto scheduler = task!runScheduler(&server);
	auto chatinterface = task!runInterface(&server);
	scheduler.executeInNewThread();
	chatinterface.executeInNewThread();

	// Keep running
	scheduler.yieldForce();
	chatinterface.yieldForce();
	return 0;
}

void runScheduler(Server* server)
{
	server.runScheduler();
}

void runInterface(Server* server)
{
	server.runInterface();
}
