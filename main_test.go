package main

import(
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHomepage(t *testing.T){
	mainHandle := mainHandler()
	http.HandleFunc("/", mainHandle)
	req, _ := http.NewRequest("GET", "", nil)
	w := httptest.NewRecorder()
	mainHandle.ServeHTTP(w, req)

	if w.Code != http.StatusOK{
		t.Errorf("The homepage returned HTTP %v instead of HTTP %v as expected.", w.Code, http.StatusOK)
	}
}
