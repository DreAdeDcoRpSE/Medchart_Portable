<?php
/** Portable SQLite adapter for the subset of MySQLi used by MedChart.
 * Keep application queries unchanged where possible; SQL dialect exceptions
 * are handled here, not scattered through the application.
 */
final class MedChartSqliteResult {
    private array $rows; private int $cursor = 0;
    public int $num_rows;
    public function __construct(array $rows) {$this->rows=$rows; $this->num_rows=count($rows);}
    public function fetch_assoc(): ?array {return $this->rows[$this->cursor++] ?? null;}
}
final class MedChartSqliteStatement {
    private MedChartSqliteConnection $db;
    private string $sql;
    private array $params=[];
    private ?MedChartSqliteResult $result=null;
    public int $affected_rows=0;
    public function __construct(MedChartSqliteConnection $db,string $sql){$this->db=$db;$this->sql=$sql;}
    public function bind_param(string $types, &...$values): bool {
        if(strlen($types)!==count($values)) throw new InvalidArgumentException('Parameter type/count mismatch');
        $this->params=[];
        foreach($values as $i=>&$value) $this->params[$i]=&$value;
        unset($value);
        return true;
    }
    public function execute(): bool {
        $sql=$this->db->translate($this->sql);
        $stmt=$this->db->pdo()->prepare($sql);
        foreach($this->params as $i=>&$value) $stmt->bindValue($i+1,$value,is_int($value)?PDO::PARAM_INT:($value===null?PDO::PARAM_NULL:PDO::PARAM_STR));
        unset($value);
        $stmt->execute();
        $this->affected_rows=$stmt->rowCount();
        $this->db->insert_id=(int)$this->db->pdo()->lastInsertId();
        $this->db->affected_rows=$this->affected_rows;
        $this->result=$stmt->columnCount() ? new MedChartSqliteResult($stmt->fetchAll(PDO::FETCH_ASSOC)) : new MedChartSqliteResult([]);
        return true;
    }
    public function get_result(): MedChartSqliteResult {return $this->result ?? new MedChartSqliteResult([]);}
}
final class MedChartSqliteConnection {
    private PDO $db;
    public int $insert_id=0;
    public int $affected_rows=0;
    public function __construct(string $path){
        $this->db=new PDO('sqlite:'.$path,null,null,[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC]);
        $this->db->exec('PRAGMA busy_timeout=10000');
        $this->db->exec('PRAGMA foreign_keys=ON');
        $this->db->exec('PRAGMA journal_mode=WAL');
    }
    public function pdo(): PDO{return $this->db;}
    public function set_charset(string $charset):bool{return strtolower($charset)==='utf8mb4';}
    public function translate(string $sql):string {
        // Preserve lockout semantics and SQLite UTC timestamps.
        $sql=preg_replace('/UNIX_TIMESTAMP\s*\(\s*attempted_at\s*\)/i',"CAST(strftime('%s', attempted_at) AS INTEGER)",$sql);
        $sql=preg_replace('/UNIX_TIMESTAMP\s*\(\s*NOW\s*\(\s*\)\s*\)/i',"CAST(strftime('%s', 'now') AS INTEGER)",$sql);
        $sql=preg_replace('/DATE_SUB\s*\(\s*NOW\s*\(\s*\)\s*,\s*INTERVAL\s+10\s+MINUTE\s*\)/i',"datetime('now', '-10 minutes')",$sql);
        $sql=preg_replace('/NOW\s*\(\s*\)\s*-\s*INTERVAL\s+24\s+HOUR/i',"datetime('now', '-24 hours')",$sql);
        return $sql;
    }
    public function prepare(string $sql):MedChartSqliteStatement{return new MedChartSqliteStatement($this,$sql);}
    public function query(string $sql): MedChartSqliteResult|bool {
        $stmt=$this->db->prepare($this->translate($sql));$stmt->execute();
        $this->affected_rows=$stmt->rowCount();$this->insert_id=(int)$this->db->lastInsertId();
        return $stmt->columnCount() ? new MedChartSqliteResult($stmt->fetchAll(PDO::FETCH_ASSOC)) : true;
    }
    public function begin_transaction():bool{return $this->db->beginTransaction();}
    public function commit():bool{return $this->db->commit();}
    public function rollback():bool{return $this->db->rollBack();}
}
