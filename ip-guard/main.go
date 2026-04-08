package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"strings"

	"github.com/lionsoul2014/ip2region/binding/golang/xdb"
)

var searcher *xdb.Searcher

type Result struct {
	IP      string `json:"ip"`
	Country string `json:"country"`
	Province string `json:"province"`
	City    string `json:"city"`
	ISP     string `json:"isp"`
	Raw     string `json:"raw"`
}

func queryHandler(w http.ResponseWriter, r *http.Request) {
	ip := r.URL.Query().Get("ip")
	if ip == "" {
		http.Error(w, `{"error":"missing ip parameter"}`, 400)
		return
	}

	region, err := searcher.SearchByStr(ip)
	if err != nil {
		http.Error(w, fmt.Sprintf(`{"error":"%s"}`, err.Error()), 500)
		return
	}

	// ip2region 格式: 国家|区域|省份|城市|ISP
	parts := strings.Split(region, "|")
	result := Result{IP: ip, Raw: region}
	if len(parts) >= 5 {
		result.Country = parts[0]
		result.Province = parts[2]
		result.City = parts[3]
		result.ISP = parts[4]
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func main() {
	dbPath := flag.String("db", "/usr/local/ip-guard/ip2region.xdb", "ip2region.xdb path")
	listen := flag.String("listen", "127.0.0.1:2060", "listen address")
	flag.Parse()

	cBuff, err := xdb.LoadContentFromFile(*dbPath)
	if err != nil {
		log.Fatalf("load ip2region.xdb failed: %s", err)
	}

	searcher, err = xdb.NewWithBuffer(cBuff)
	if err != nil {
		log.Fatalf("create searcher failed: %s", err)
	}
	defer searcher.Close()

	http.HandleFunc("/ip", queryHandler)
	log.Printf("ip-guard started on %s", *listen)
	log.Fatal(http.ListenAndServe(*listen, nil))
}
