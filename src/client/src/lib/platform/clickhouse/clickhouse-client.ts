import { constructURL, parseQueryStringToObject } from "@/utils/parser";
import { ClickHouseClient, createClient } from "@clickhouse/client";
import { DatabaseConfig } from "@prisma/client";
import { createPool, Pool } from "generic-pool";
import asaw from "@/utils/asaw";

interface ClickHouseConnectionInfo {
	username: string;
	password: string;
	url: string;
	database: string;
	http_headers: Record<string, string>;
}

const getClickHouseFactoryOptions = (
	connectionObject: ClickHouseConnectionInfo
) => ({
	create: (): Promise<ClickHouseClient> => {
		const client: ClickHouseClient = createClient({
			...connectionObject,
			request_timeout: 30000, // 30 second timeout for cloud connections
			max_open_connections: 5,
		});
		return Promise.resolve(client);
	},
	destroy: (client: ClickHouseClient) => client.close(),
	validate: async (client: ClickHouseClient): Promise<boolean> => {
		const [err, result] = await asaw(client.ping());
		if (err || !result.success) {
			client.close();
			throw new Error(result.error?.toString() || "Unable to ping the db");
		}

		return true;
	},
});

export default function createClickhousePool(
	dbConfig: DatabaseConfig
): Pool<ClickHouseClient> {
	const connectionObject: ClickHouseConnectionInfo = {
		username: dbConfig.username,
		password: dbConfig.password || "",
		url: constructURL(dbConfig.host, dbConfig.port),
		database: dbConfig.database,
		http_headers: parseQueryStringToObject(dbConfig.query || ""),
	};

	return createPool(getClickHouseFactoryOptions(connectionObject), {
		max: 10,
		min: 2,
		idleTimeoutMillis: 60000,
		maxWaitingClients: 10,
		testOnBorrow: true,
		acquireTimeoutMillis: 30000, // Increased from 5s to 30s for cloud connections
		evictionRunIntervalMillis: 10000,
	});
}
