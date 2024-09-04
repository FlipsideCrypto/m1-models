-- depends_on: {{ ref('bronze_evm__streamline_blocks') }}
{{ config(
    materialized = 'incremental',
    unique_key = "block_number",
    cluster_by = "block_timestamp::date",
    tags = ['core'],
    merge_exclude_columns = ["inserted_timestamp"],
    post_hook = "ALTER TABLE {{ this }} ADD SEARCH OPTIMIZATION ON EQUALITY(hash,parent_hash,receipts_root,sha3_uncles,state_root,transactions_root)",
) }}

SELECT
    DATA,
    VALUE :BLOCK_NUMBER :: INT AS block_number,
    utils.udf_hex_to_int(
        DATA :result :baseFeePerGas :: STRING
    ) :: INT AS base_fee_per_gas,
    utils.udf_hex_to_int(
        DATA :result :difficulty :: STRING
    ) :: INT AS difficulty,
    DATA :result :extraData :: STRING AS extra_data,
    utils.udf_hex_to_int(
        DATA :result :gasLimit :: STRING
    ) :: INT AS gas_limit,
    utils.udf_hex_to_int(
        DATA :result :gasUsed :: STRING
    ) :: INT AS gas_used,
    DATA :result :hash :: STRING AS HASH,
    DATA :result :logsBloom :: STRING AS logs_bloom,
    DATA :result :miner :: STRING AS miner,
    DATA :result :mixHash :: STRING AS mixHash,
    utils.udf_hex_to_int(
        DATA :result :nonce :: STRING
    ) :: INT AS nonce,
    utils.udf_hex_to_int(
        DATA :result :number :: STRING
    ) :: INT AS NUMBER,
    DATA :result :parentHash :: STRING AS parent_hash,
    DATA :result :receiptsRoot :: STRING AS receipts_root,
    DATA :result :sha3Uncles :: STRING AS sha3_uncles,
    utils.udf_hex_to_int(
        DATA :result :size :: STRING
    ) :: INT AS SIZE,
    DATA :result :stateRoot :: STRING AS state_root,
    utils.udf_hex_to_int(
        DATA :result :timestamp :: STRING
    ) :: TIMESTAMP AS block_timestamp,
    IFNULL(
        utils.udf_hex_to_int(
            DATA :result :totalDifficulty :: STRING
        ) :: INT,
        0
    ) AS total_difficulty,
    ARRAY_SIZE(
        DATA :result :transactions
    ) AS tx_count,
    DATA :result :transactionsRoot :: STRING AS transactions_root,
    DATA :result :uncles AS uncles,
    {{ dbt_utils.generate_surrogate_key(
        ['block_number']
    ) }} AS blocks_id,
    SYSDATE() AS inserted_timestamp,
    SYSDATE() AS modified_timestamp,
    '{{ invocation_id }}' AS _invocation_id
FROM

{% if is_incremental() %}
{{ ref('bronze_evm__streamline_blocks') }}
WHERE
    inserted_timestamp >= (
        SELECT
            MAX(inserted_timestamp) inserted_timestamp
        FROM
            {{ this }}
    )
{% else %}
    {{ ref('bronze_evm__streamline_FR_blocks') }}
{% endif %}

qualify(ROW_NUMBER() over (PARTITION BY block_number
ORDER BY
    inserted_timestamp DESC)) = 1
