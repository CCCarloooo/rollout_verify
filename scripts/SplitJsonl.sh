input="/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/data/v2/PreEvalMerge.jsonl"
prefix="/mnt/new_pfs/liming_team/auroraX/mxd/a_x1/data/v2/processed/processed_"

# 打batch的原则是，每个batch要是32的倍数
# 8192 -> 1024
awk -v n1=1024 -v n2=1024 -v k=7 -v pre="$prefix" '
{
    if (NR <= n1 * k) {
        f = int((NR-1)/n1);
        fname = sprintf("%s%02d.jsonl", pre, f);
    } else {
        fname = sprintf("%s%02d.jsonl", pre, k);
    }
    print >> fname
}
' "$input"

# awk -v n1=132480 -v n2=133984 -v k=31 -v pre="$prefix" ' 