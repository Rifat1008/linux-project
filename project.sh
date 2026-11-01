#!/bin/bash

DIR="$(cd "$(dirname "$0")" && pwd)"
FILE="$DIR/expenses.txt"
touch "$FILE"
sort -t'|' -k1,1 -s -o "$FILE" "$FILE"

W=78
RED=$'\033[1;31m'; GRN=$'\033[1;32m'; YEL=$'\033[1;33m'; BLU=$'\033[1;34m'
MAG=$'\033[1;35m'; CYN=$'\033[1;36m'; DIM=$'\033[2m'; RST=$'\033[0m'
CATS=(Food Transport Shopping Bills Education Health Entertainment Other)

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

ok_msg()  { printf '\n  %s✔  %s%s\n' "$GRN" "$1" "$RST"; }
err()     { printf '\n  %s✘  %s%s\n' "$RED" "$1" "$RST"; }
pause()   { echo; read -rp "  Press Enter to return to the menu..." _; }

valid_date()   { [[ $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; }
valid_amount() { [[ $1 =~ ^[0-9]+(\.[0-9]{1,2})?$ ]]; }
sortfile()     { sort -t'|' -k1,1 -s -o "$FILE" "$FILE"; }

dashboard() {
    local n=0 total=0
    if [ -s "$FILE" ]; then
        n=$(wc -l < "$FILE")
        total=$(awk -F'|' '{sum+=$3} END {print sum}' "$FILE")
    fi
    box_top "DASHBOARD"
    row "Total Records  : $n"
    row "Total Expense  : $total BDT"
    box_bot
}

menu() {
    local s
    mrow() { printf -v s '%-38s%s' "$1" "$2"; row "$s"; }
    box_top "MAIN MENU"
    mrow "[ 1]  Add Expense"          "[ 4]  Edit an Expense"
    mrow "[ 2]  View All Expenses"    "[ 5]  Delete an Expense"
    mrow "[ 3]  Search Expenses"      "[ 0]  Exit"
    box_bot
}

records_table() {
    if [ ! -s "$FILE" ]; then
        err "No expense records found."
        return 1
    fi
    printf '%s' "$BLU"
    echo "----------------------------------------------------------------------------"
    printf '%-4s | %-12s | %-15s | %-10s | %-20s\n' "No" "Date" "Category" "Amount" "Description"
    echo "----------------------------------------------------------------------------"
    printf '%s' "$RST"
    
    awk -F'|' '{printf "%-4s | %-12s | %-15s | %-10s | %-20s\n", NR, $1, $2, $3, $4}' "$FILE"
    
    printf '%s' "$BLU"
    echo "----------------------------------------------------------------------------"
    printf '%s' "$RST"
}

add_expense() {
    banner "ADD NEW EXPENSE"
    local d c a desc i ch
    
    read -rp "  Date (YYYY-MM-DD) [Enter = today] : " d
    d=${d:-$(date +%F)}
    valid_date "$d" || { err "Invalid date format."; pause; return; }

    echo
    for i in "${!CATS[@]}"; do
        printf '   %s%d%s)  %s\n' "$CYN" $((i+1)) "$RST" "${CATS[$i]}"
    done
    read -rp "  Select category [1-8] : " ch
    if [[ $ch =~ ^[1-8]$ ]]; then
        c=${CATS[$((ch-1))]}
    else
        err "Invalid category choice."
        pause
        return
    fi

    read -rp "  Amount (BDT) : " a
    valid_amount "$a" || { err "Invalid amount."; pause; return; }

    read -rp "  Description : " desc
    desc=${desc:-"-"}

    echo "$d|$c|$a|$desc" >> "$FILE"
    sortfile
    ok_msg "Expense successfully added!"
    pause
}

view_all() {
    banner "ALL EXPENSE RECORDS"
    records_table
    pause
}

search_expense() {
    banner "SEARCH EXPENSES"
    local keyword
    read -rp "  Enter keyword to search (Date/Category/Desc): " keyword
    [ -z "$keyword" ] && { err "Keyword cannot be empty."; pause; return; }
    
    echo
    grep -i "$keyword" "$FILE" > /tmp/search_res.txt
    if [ -s /tmp/search_res.txt ]; then
        printf '%s' "$BLU"
        echo "----------------------------------------------------------------------------"
        printf '%-4s | %-12s | %-15s | %-10s | %-20s\n' "No" "Date" "Category" "Amount" "Description"
        echo "----------------------------------------------------------------------------"
        printf '%s' "$RST"
        cat /tmp/search_res.txt | awk -F'|' '{printf "%-4s | %-12s | %-15s | %-10s | %-20s\n", NR, $1, $2, $3, $4}'
        printf '%s' "$BLU"
        echo "----------------------------------------------------------------------------"
        printf '%s' "$RST"
    else
        err "No matching records found."
    fi
    rm -f /tmp/search_res.txt
    pause
}

edit_expense() {
    banner "EDIT EXPENSE"
    records_table || { pause; return; }
    local n total od oc oa odesc d c a desc
    echo
    read -rp "  Record number to edit : " n
    total=$(wc -l < "$FILE")
    if ! [[ $n =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt "$total" ]; then
        err "Invalid record number."
        pause
        return
    fi
    IFS='|' read -r od oc oa odesc < <(sed -n "${n}p" "$FILE")
    printf '\n  %sPress Enter to keep the current value.%s\n\n' "$DIM" "$RST"
    read -rp "  Date        [$od] : " d;    d=${d:-$od}
    read -rp "  Amount      [$oa] : " a;    a=${a:-$oa}
    read -rp "  Description [$odesc] : " desc; desc=${desc:-$odesc}
    
    awk -F'|' -v OFS='|' -v n="$n" -v d="$d" -v c="$oc" -v a="$a" -v s="$desc" \
        'NR==n { $1=d; $2=c; $3=a; $4=s } 1' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
    sortfile
    ok_msg "Record updated successfully."
    pause
}

delete_expense() {
    banner "DELETE EXPENSE"
    records_table || { pause; return; }
    local n total yn
    echo
    read -rp "  Record number to delete : " n
    total=$(wc -l < "$FILE")
    if ! [[ $n =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt "$total" ]; then
        err "Invalid record number."
        pause
        return
    fi
    read -rp "  Delete record $n permanently? (y/n) : " yn
    if [[ $yn == [Yy] ]]; then
        sed -i "${n}d" "$FILE"
        ok_msg "Record deleted."
    else
        err "Deletion cancelled."
    fi
    pause
}

goodbye() {
    banner
    center "Thank you for using Daily Expense Manager"
    center "Spend smart. Save more."
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
        3)  search_expense ;;
        4)  edit_expense ;;
        5)  delete_expense ;;
        0)  goodbye; exit 0 ;;
        *)  err "Invalid choice. Please select 0-5."; sleep 1 ;;
    esac
done