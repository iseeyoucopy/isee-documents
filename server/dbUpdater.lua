CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `isee_documents` (
            `identifier` varchar(50) NOT NULL,
            `charidentifier` varchar(50) NOT NULL,
            `doc_type` varchar(50) NOT NULL,
            `firstname` varchar(50) DEFAULT NULL,
            `lastname` varchar(50) DEFAULT NULL,
            `nickname` varchar(50) DEFAULT NULL,
            `job` varchar(50) DEFAULT NULL,
            `age` varchar(50) DEFAULT NULL,
            `gender` varchar(50) DEFAULT NULL,
            `date` varchar(50) NOT NULL,
            `picture` longtext DEFAULT NULL,
            `expire_date` date DEFAULT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
    ]])
    
    MySQL.query.await("ALTER TABLE `isee_documents` ADD PRIMARY KEY IF NOT EXISTS (`identifier`, `charidentifier`, `doc_type`)")

    -- Commit any pending transactions to ensure changes are saved
    MySQL.query.await("COMMIT;")

    print("Database tables for `isee_documents` created and updated successfully.")
end)
