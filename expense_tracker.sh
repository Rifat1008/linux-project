#!/bin/bash

DIR="$(cd "$(dirname "$0")" && pwd)"
FILE="$DIR/expenses.txt"
BUDGET="$DIR/budget.txt"
touch "$FILE"
sort -t'|' -k1,1 -s -o "$FILE" "$FILE"

W=78
RED=$'\033[1;31m'; GRN=$'\033[1;32m'; YEL=$'\033[1;33m'; BLU=$'\033[1;34m'
MAG=$'\033[1;35m'; CYN=$'\033[1;36m'; DIM=$'\033[2m'; RST=$'\033[0m'
CATS=(Food Transport Shopping Bills Education Health Entertainment Other)
AWKF='function ok(k,f){ if(k=="") return 1; if(f==0) return index(tolower($0),tolower(k))>0; return tolower($f)==tolower(k) }'

rep() { local i s=""; for ((i=0;i<$1;i++)); do s+="$2"; done; printf '%s' "$s"; }

center() {
    local t="$1" pad
    pad=$(( (W-2-${#t})/2 ))
    printf '║%*s%s%*s║\n' "$pad" '' "$t" $((W-2-pad-${#t})) ''
}

banner() {
    clear
    printf '%s' "$CYN"
    printf '╔%s╗\n' "$(rep $((W-2)) ═)"
    center ""
    center "D A I L Y   E X P E N S E   M A N A G E R"
    center "Linux Lab Project  |  Bash Shell Scripting"
    center ""
    printf '╚%s╝\n' "$(rep $((W-2)) ═)"
    printf '%s' "$RST"
    if [ -n "$1" ]; then
        printf '\n  %s%s%s\n' "$YEL" "$1" "$RST"
        printf '  %s%s%s\n\n' "$DIM" "$(rep $((W-4)) ─)" "$RST"
    fi
}

row()     { printf '%s│ %-*s │%s\n' "$MAG" $((W-4)) "$1" "$RST"; }
box_top() { printf '%s┌─ %s %s┐%s\n' "$MAG" "$1" "$(rep $((W-5-${#1})) ─)" "$RST"; }
box_bot() { printf '%s└%s┘%s\n' "$MAG" "$(rep $((W-2)) ─)" "$RST"; }

tline() {
    local l=$1 m=$2 r=$3 out first=1 w
    shift 3
    out="$l"
    for w in "$@"; do
        [ $first -eq 0 ] && out+="$m"
        out+="$(rep $((w+2)) ─)"
        first=0
    done
    printf '%s%s\n' "$out" "$r"
}

ok_msg()  { printf '\n  %s✔  %s%s\n' "$GRN" "$1" "$RST"; }
err()     { printf '\n  %s✘  %s%s\n' "$RED" "$1" "$RST"; }
warn()    { printf '\n  %s⚠  %s%s\n' "$YEL" "$1" "$RST"; }
pause()   { echo; read -rp "  Press Enter to return to the menu..." _; }

valid_date()   { [[ $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && date -d "$1" >/dev/null 2>&1; }
valid_month()  { [[ $1 =~ ^[0-9]{4}-(0[1-9]|1[0-2])$ ]]; }
valid_amount() { [[ $1 =~ ^[0-9]+(\.[0-9]{1,2})?$ ]] && awk -v a="$1" 'BEGIN { exit !(a>0) }'; }
norm()         { printf '%s' "$1" | tr -d '|' | awk '{ $1=$1; print toupper(substr($0,1,1)) tolower(substr($0,2)) }'; }
sortfile()     { sort -t'|' -k1,1 -s -o "$FILE" "$FILE"; }

dashboard() {
    local t m d mo n tc tv b pct len st rem col bartxt r pad
    t=$(date +%F); m=$(date +%Y-%m)
    IFS='|' read -r d mo n tc tv < <(awk -F'|' -v t="$t" -v m="$m" '
        { n++; if ($1==t) d+=$3; if (index($1,m)==1) { mo+=$3; c[$2]+=$3 } }
        END { for (k in c) if (c[k]>mx) { mx=c[k]; top=k }
              printf "%.2f|%.2f|%d|%s|%.2f\n", d, mo, n, (top==""?"-":top), mx }' "$FILE")
    local s
    box_top "DASHBOARD"
    printf -v s '%-38s%s' "Today          : $d BDT" "This Month : $mo BDT"
    row "$s"
    printf -v s '%-38s%s' "Total Records  : $n" "Top Category : $tc"
    row "$s"
    if [ -s "$BUDGET" ]; then
        b=$(<"$BUDGET")
        read -r pct len st rem < <(awk -v u="$mo" -v b="$b" 'BEGIN {
            p=u*100/b; l=int(p*30/100+0.5); if (l>30) l=30
            s=(p>=100)?2:((p>=80)?1:0); printf "%.1f %d %d %.2f", p, l, s, b-u }')
        case $st in 2) col=$RED ;; 1) col=$YEL ;; *) col=$GRN ;; esac
        printf -v s '%-38s%s' "Monthly Budget : $b BDT" "Remaining : $rem BDT"
        row "$s"
        bartxt="[$(rep "$len" █)$(rep $((30-len)) ░)]"
        r="  ${pct}% of budget used"
        pad=$((W-4-32-${#r}))
        printf '%s│ %s%s%s%s%*s │%s\n' "$MAG" "$col" "$bartxt" "$MAG" "$r" "$pad" '' "$RST"
    else
        row "Monthly Budget : Not set  (use option 10 to set one)"
    fi
    box_bot
}

menu() {
    local s
    mrow() { printf -v s '%-38s%s' "$1" "$2"; row "$s"; }
    box_top "MAIN MENU"
    mrow "[ 1]  Add Expense"            "[ 7]  Search Expenses"
    mrow "[ 2]  View All Expenses"      "[ 8]  Edit an Expense"
    mrow "[ 3]  Day-wise Report"        "[ 9]  Delete an Expense"
    mrow "[ 4]  Topic-wise Report"      "[10]  Set Monthly Budget"
    mrow "[ 5]  Daily Total"            "[11]  Export to CSV"
    mrow "[ 6]  Monthly Report"         "[ 0]  Exit"
    box_bot
}

records_table() {
    local k="$1" f="${2:-0}" rows st n t
    rows=$(awk -F'|' -v k="$k" -v f="$f" "$AWKF"' ok(k,f) {
        printf "│ %-4d │ %-10s │ %-13s │ %10.2f │ %-25s │\n", NR, $1, substr($2,1,13), $3, substr($4,1,25) }' "$FILE")
    if [ -z "$rows" ]; then err "No matching records found."; return 1; fi
    st=$(awk -F'|' -v k="$k" -v f="$f" "$AWKF"' ok(k,f) { n++; t+=$3 } END { printf "%d|%.2f", n, t }' "$FILE")
    IFS='|' read -r n t <<< "$st"
    printf '%s' "$BLU"
    tline ┌ ┬ ┐ 4 10 13 10 25
    printf '│ %-4s │ %-10s │ %-13s │ %10s │ %-25s │\n' No Date Category Amount Description
    tline ├ ┼ ┤ 4 10 13 10 25
    printf '%s' "$RST"
    printf '%s\n' "$rows"
    printf '%s' "$BLU"
    tline ├ ┼ ┤ 4 10 13 10 25
    printf '│ %-4s │ %-10s │ %-13s │ %10s │ %-25s │\n' "" "" TOTAL "$t" "$n record(s)"
    tline └ ┴ ┘ 4 10 13 10 25
    printf '%s' "$RST"
    return 0
}

cat_table() {
    local mf="$1" data c n t p len bar st tot cnt
    data=$(awk -F'|' -v m="$mf" 'm=="" || index($1,m)==1 { s[$2]+=$3; c[$2]++; T+=$3 }
        END { for (k in s) if (s[k]>mx) mx=s[k]
              for (k in s) printf "%s|%d|%.2f|%.1f|%d\n", k, c[k], s[k], s[k]*100/T, int(s[k]*20/mx+0.5) }' "$FILE" | sort -t'|' -k3,3nr)
    if [ -z "$data" ]; then err "No records for this period."; return 1; fi
    st=$(awk -F'|' '{ t+=$3; n+=$2 } END { printf "%.2f|%d", t, n }' <<< "$data")
    IFS='|' read -r tot cnt <<< "$st"
    printf '%s' "$BLU"
    tline ┌ ┬ ┐ 14 7 12 6 20
    printf '│ %-14s │ %7s │ %12s │ %-6s │ %-20s │\n' Category Entries "Total (BDT)" Share Graph
    tline ├ ┼ ┤ 14 7 12 6 20
    printf '%s' "$RST"
    while IFS='|' read -r c n t p len; do
        bar="$(rep "$len" █)$(rep $((20-len)) ' ')"
        printf '│ %-14s │ %7d │ %12s │ %5s%% │ %s%s%s │\n' "${c:0:14}" "$n" "$t" "$p" "$GRN" "$bar" "$RST"
    done <<< "$data"
    printf '%s' "$BLU"
    tline ├ ┼ ┤ 14 7 12 6 20
    printf '│ %-14s │ %7d │ %12s │ %-6s │ %-20s │\n' TOTAL "$cnt" "$tot" "100%" ""
    tline └ ┴ ┘ 14 7 12 6 20
    printf '%s' "$RST"
    return 0
}

add_expense() {
    banner "ADD NEW EXPENSE"
    local d i ch c a desc month st
    read -rp "  Date (YYYY-MM-DD) [Enter = today] : " d
    d=${d:-$(date +%F)}
    valid_date "$d" || { err "Invalid date."; pause; return; }
    echo
    for i in "${!CATS[@]}"; do
        printf '   %s%d%s)  %s\n' "$CYN" $((i+1)) "$RST" "${CATS[$i]}"
    done
    printf '   %s9%s)  Custom category\n\n' "$CYN" "$RST"
    read -rp "  Select category [1-9] : " ch
    if [[ $ch =~ ^[1-8]$ ]]; then
        c=${CATS[$((ch-1))]}
    elif [ "$ch" = "9" ]; then
        read -rp "  Enter category name : " c
        c=$(norm "$c")
        [ -z "$c" ] && { err "Category cannot be empty."; pause; return; }
    else
        err "Invalid category choice."; pause; return
    fi
    read -rp "  Amount (BDT) : " a
    valid_amount "$a" || { err "Invalid amount."; pause; return; }
    read -rp "  Description : " desc
    desc=${desc//|/}
    [ -z "$desc" ] && desc="-"
    echo "$d|$c|$a|$desc" >> "$FILE"
    sortfile
    ok_msg "Expense of $a BDT saved under $c."
    if [ -s "$BUDGET" ]; then
        month=${d:0:7}
        st=$(awk -F'|' -v m="$month" -v b="$(<"$BUDGET")" 'index($1,m)==1 { u+=$3 }
            END { if (u>b) print 2; else if (u>=0.8*b) print 1; else print 0 }' "$FILE")
        [ "$st" = "2" ] && err "Budget exceeded for $month!"
        [ "$st" = "1" ] && warn "You have used over 80% of the budget for $month."
    fi
    pause
}

view_all() {
    banner "ALL EXPENSE RECORDS"
    records_table ""
    pause
}

daywise() {
    banner "DAY-WISE EXPENSE REPORT"
    [ -s "$FILE" ] || { err "No records found."; pause; return; }
    local mf data d n t len wd bar st tot cnt top avg days
    read -rp "  Month filter (YYYY-MM) [Enter = all] : " mf
    if [ -n "$mf" ] && ! valid_month "$mf"; then err "Invalid month."; pause; return; fi
    data=$(awk -F'|' -v m="$mf" 'm=="" || index($1,m)==1 { s[$1]+=$3; c[$1]++ }
        END { for (d in s) if (s[d]>mx) mx=s[d]
              for (d in s) printf "%s|%d|%.2f|%d\n", d, c[d], s[d], int(s[d]*20/mx+0.5) }' "$FILE" | sort)
    [ -z "$data" ] && { err "No records for this period."; pause; return; }
    echo
    printf '%s' "$BLU"
    tline ┌ ┬ ┐ 10 3 7 12 20
    printf '│ %-10s │ %-3s │ %7s │ %12s │ %-20s │\n' Date Day Entries "Total (BDT)" Graph
    tline ├ ┼ ┤ 10 3 7 12 20
    printf '%s' "$RST"
    while IFS='|' read -r d n t len; do
        wd=$(date -d "$d" +%a)
        bar="$(rep "$len" █)$(rep $((20-len)) ' ')"
        printf '│ %-10s │ %-3s │ %7d │ %12s │ %s%s%s │\n' "$d" "$wd" "$n" "$t" "$GRN" "$bar" "$RST"
    done <<< "$data"
    st=$(awk -F'|' '{ t+=$3; n+=$2; d++ } END { printf "%.2f|%d|%d|%.2f", t, n, d, t/d }' <<< "$data")
    IFS='|' read -r tot cnt days avg <<< "$st"
    top=$(sort -t'|' -k3,3nr <<< "$data" | head -1 | awk -F'|' '{ printf "%s (%.2f BDT)", $1, $3 }')
    printf '%s' "$BLU"
    tline ├ ┼ ┤ 10 3 7 12 20
    printf '│ %-10s │ %-3s │ %7d │ %12s │ %-20s │\n' TOTAL "" "$cnt" "$tot" ""
    tline └ ┴ ┘ 10 3 7 12 20
    printf '%s' "$RST"
    printf '\n  %sDays with spending :%s %s\n' "$CYN" "$RST" "$days"
    printf '  %sAverage per day    :%s %s BDT\n' "$CYN" "$RST" "$avg"
    printf '  %sHighest spending   :%s %s\n\n' "$CYN" "$RST" "$top"
    read -rp "  View details of a day? (YYYY-MM-DD / Enter to skip) : " d
    if [ -n "$d" ]; then
        valid_date "$d" || { err "Invalid date."; pause; return; }
        echo
        records_table "$d" 1
    fi
    pause
}

topicwise() {
    banner "TOPIC-WISE (CATEGORY) EXPENSE REPORT"
    [ -s "$FILE" ] || { err "No records found."; pause; return; }
    local mf c
    read -rp "  Month filter (YYYY-MM) [Enter = all] : " mf
    if [ -n "$mf" ] && ! valid_month "$mf"; then err "Invalid month."; pause; return; fi
    echo
    cat_table "$mf" || { pause; return; }
    echo
    read -rp "  View details of a category? (name / Enter to skip) : " c
    if [ -n "$c" ]; then
        echo
        records_table "$c" 2
    fi
    pause
}

daily_total() {
    banner "DAILY TOTAL"
    local d
    read -rp "  Date (YYYY-MM-DD) [Enter = today] : " d
    d=${d:-$(date +%F)}
    valid_date "$d" || { err "Invalid date."; pause; return; }
    printf '\n  %sDate :%s %s (%s)\n\n' "$CYN" "$RST" "$d" "$(date -d "$d" +%A)"
    records_table "$d" 1
    pause
}

monthly_report() {
    banner "MONTHLY REPORT"
    local m st t n days mx md mc hd hdd dim avg1 avg2 b rem pct s
    read -rp "  Month (YYYY-MM) [Enter = this month] : " m
    m=${m:-$(date +%Y-%m)}
    valid_month "$m" || { err "Invalid month."; pause; return; }
    st=$(awk -F'|' -v m="$m" 'index($1,m)==1 { t+=$3; n++; ds[$1]+=$3; if ($3>mx) { mx=$3; md=$4; mc=$2 } }
        END { for (d in ds) { days++; if (ds[d]>hd) { hd=ds[d]; hdd=d } }
              printf "%.2f|%d|%d|%.2f|%s|%s|%.2f|%s\n", t, n, days, mx, md, mc, hd, hdd }' "$FILE")
    IFS='|' read -r t n days mx md mc hd hdd <<< "$st"
    if [ "$n" -eq 0 ]; then err "No records found for $m."; pause; return; fi
    dim=$(date -d "$m-01 +1 month -1 day" +%d)
    avg1=$(awk -v t="$t" -v d="$days" 'BEGIN { printf "%.2f", t/d }')
    avg2=$(awk -v t="$t" -v d="$dim" 'BEGIN { printf "%.2f", t/d }')
    echo
    box_top "SUMMARY FOR $m"
    printf -v s '%-38s%s' "Total Spent      : $t BDT" "Entries : $n"
    row "$s"
    printf -v s '%-38s%s' "Avg / Spend Day  : $avg1 BDT" "Avg / Calendar Day : $avg2 BDT"
    row "$s"
    row "Highest Day      : $hdd ($hd BDT)"
    row "Biggest Expense  : $mx BDT  [$mc - ${md:0:30}]"
    if [ -s "$BUDGET" ]; then
        b=$(<"$BUDGET")
        rem=$(awk -v t="$t" -v b="$b" 'BEGIN { printf "%.2f", b-t }')
        pct=$(awk -v t="$t" -v b="$b" 'BEGIN { printf "%.1f", t*100/b }')
        printf -v s '%-38s%s' "Budget           : $b BDT" "Used : $pct%   Left : $rem BDT"
        row "$s"
    fi
    box_bot
    echo
    cat_table "$m"
    pause
}

search_expense() {
    banner "SEARCH EXPENSES"
    local k
    read -rp "  Enter keyword (date, category or description) : " k
    [ -z "$k" ] && { err "Keyword cannot be empty."; pause; return; }
    echo
    records_table "$k" 0
    pause
}

edit_expense() {
    banner "EDIT EXPENSE"
    [ -s "$FILE" ] || { err "No records found."; pause; return; }
    records_table "" || { pause; return; }
    local n total od oc oa odesc d c a desc
    echo
    read -rp "  Record number to edit : " n
    total=$(wc -l < "$FILE")
    if ! [[ $n =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt "$total" ]; then
        err "Invalid record number."; pause; return
    fi
    IFS='|' read -r od oc oa odesc < <(sed -n "${n}p" "$FILE")
    printf '\n  %sPress Enter to keep the current value.%s\n\n' "$DIM" "$RST"
    read -rp "  Date        [$od] : " d;    d=${d:-$od}
    valid_date "$d" || { err "Invalid date."; pause; return; }
    read -rp "  Category    [$oc] : " c;    c=${c:-$oc}; c=$(norm "$c")
    [ -z "$c" ] && { err "Category cannot be empty."; pause; return; }
    read -rp "  Amount      [$oa] : " a;    a=${a:-$oa}
    valid_amount "$a" || { err "Invalid amount."; pause; return; }
    read -rp "  Description [$odesc] : " desc; desc=${desc:-$odesc}; desc=${desc//|/}
    awk -F'|' -v OFS='|' -v n="$n" -v d="$d" -v c="$c" -v a="$a" -v s="$desc" \
        'NR==n { $1=d; $2=c; $3=a; $4=s } 1' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
    sortfile
    ok_msg "Record updated successfully."
    pause
}

delete_expense() {
    banner "DELETE EXPENSE"
    [ -s "$FILE" ] || { err "No records found."; pause; return; }
    records_table "" || { pause; return; }
    local n total yn
    echo
    read -rp "  Record number to delete : " n
    total=$(wc -l < "$FILE")
    if ! [[ $n =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt "$total" ]; then
        err "Invalid record number."; pause; return
    fi
    read -rp "  Delete record $n permanently? (y/n) : " yn
    if [[ $yn == [Yy] ]]; then
        sed -i "${n}d" "$FILE"
        ok_msg "Record deleted."
    else
        warn "Deletion cancelled."
    fi
    pause
}

set_budget() {
    banner "SET MONTHLY BUDGET"
    local b
    [ -s "$BUDGET" ] && printf '  Current budget : %s%s BDT%s\n\n' "$CYN" "$(<"$BUDGET")" "$RST"
    read -rp "  New monthly budget in BDT (0 to remove) : " b
    if [ "$b" = "0" ]; then
        : > "$BUDGET"
        ok_msg "Budget removed."
    elif valid_amount "$b"; then
        echo "$b" > "$BUDGET"
        ok_msg "Monthly budget set to $b BDT."
    else
        err "Invalid amount."
    fi
    pause
}

export_csv() {
    banner "EXPORT TO CSV"
    [ -s "$FILE" ] || { err "No records to export."; pause; return; }
    local out="$DIR/expenses_export.csv"
    {
        echo "Date,Category,Amount,Description"
        awk -F'|' -v OFS=',' '{ gsub(/"/, "\"\"", $4); print $1, $2, $3, "\"" $4 "\"" }' "$FILE"
    } > "$out"
    ok_msg "Exported $(wc -l < "$FILE") records."
    printf '  File : %s%s%s\n' "$CYN" "$out" "$RST"
    pause
}

goodbye() {
    banner
    printf '%s' "$GRN"
    printf '┌%s┐\n' "$(rep $((W-2)) ─)"
    center "Thank you for using Daily Expense Manager"
    center "Track every taka. Spend smart."
    printf '└%s┘\n' "$(rep $((W-2)) ─)"
    printf '%s\n' "$RST"
}

while true; do
    banner
    dashboard
    echo
    menu
    echo
    read -rp "  Enter your choice : " ch
    case $ch in
        1)  add_expense ;;
        2)  view_all ;;
        3)  daywise ;;
        4)  topicwise ;;
        5)  daily_total ;;
        6)  monthly_report ;;
        7)  search_expense ;;
        8)  edit_expense ;;
        9)  delete_expense ;;
        10) set_budget ;;
        11) export_csv ;;
        0)  goodbye; exit 0 ;;
        *)  err "Invalid choice. Please select 0-11."; sleep 1 ;;
    esac
done
