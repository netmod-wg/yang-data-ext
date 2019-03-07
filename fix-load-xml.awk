/^<data/ { next; }
/^<\/data/ { next; }
/^<config/ { next; }
/^<\/config/ { next; }

/<!-- ALT/ { next; }
/SKIP-NEXT/ { skip_next=1; next; }
skip_next == 1 { skip_next = 0; next; }

{print $0; }
