package util

import (
	"io"
	"net/http"

	log "github.com/DggHQ/dggarchiver-logger"
)

func DownloadThumbnail(url string) io.Reader {
	response, err := http.Get(url)
	if err != nil {
		log.Errorf("HTTP error during thumbnail downloading: %s", err)
		return nil
	}

	if response.StatusCode != 200 {
		log.Errorf("Status code != 200, giving up.")
		return nil
	}

	return response.Body
}
