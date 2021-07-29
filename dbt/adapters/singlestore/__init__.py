from dbt.adapters.singlestore.connections import MySQLConnectionManager
from dbt.adapters.singlestore.connections import MySQLCredentials
from dbt.adapters.singlestore.relation import MySQLRelation
from dbt.adapters.singlestore.column import MySQLColumn
from dbt.adapters.singlestore.impl import MySQLAdapter

from dbt.adapters.base import AdapterPlugin
from dbt.include import singlestore


Plugin = AdapterPlugin(
    adapter=MySQLAdapter,
    credentials=MySQLCredentials,
    include_path=singlestore.PACKAGE_PATH)
