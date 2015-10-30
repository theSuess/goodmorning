import std.stdio;
import std.process;
import std.getopt;
import std.parallelism;
import std.experimental.logger;

import server;
import utils;

int main(string[] args)
{
	string token;
	debug{ token = environment["bottoken"];}
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

	info("Setting up server");
	auto settings = ServerSettings(token);
	settings.dbpath = dbpath;
	auto server = new Server(settings);
	
	info("Setting up scheduler");
	auto scheduler = task!runScheduler(&server);

	info("Setting up interface");
	auto chatinterface = task!runInterface(&server);

	info("Starting scheduler and interface...");
	scheduler.executeInNewThread();
	chatinterface.executeInNewThread();
	info("Success! Server is now running");

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
