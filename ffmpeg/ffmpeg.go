package ffmpeg

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"

	log "github.com/DggHQ/dggarchiver-logger"
	"github.com/DggHQ/dggarchiver-worker/util"
	"github.com/disintegration/imaging"
	ffmpeg "github.com/u2takey/ffmpeg-go"
	ffprobe "gopkg.in/vansante/go-ffprobe.v2"
)

// one of the examples from https://github.com/u2takey/ffmpeg-go
func readFrameAsJpeg(inFileName string, frameNum int) io.Reader {
	buf := bytes.NewBuffer(nil)
	err := ffmpeg.Input(inFileName).
		Filter("select", ffmpeg.Args{fmt.Sprintf("gte(n,%d)", frameNum)}).
		Output("pipe:", ffmpeg.KwArgs{"vframes": 1, "format": "image2", "vcodec": "mjpeg"}).
		WithOutput(buf, os.Stdout).
		Run()
	if err != nil {
		return nil
	}
	return buf
}

// one of the examples from https://github.com/u2takey/ffmpeg-go
func SaveFrameAsThumbnail(inFileName string, frameNum int, url string) string {
	split := strings.Split(inFileName, ".")
	outFileName := fmt.Sprintf("%s-thumb.jpg", split[0])

	reader := readFrameAsJpeg(inFileName, frameNum)
	if reader == nil {
		log.Errorf("Wasn't able to create a thumbnail from \"%s\" (going to try to download one from YouTube)", inFileName)
		reader = util.DownloadThumbnail(url)
		if reader == nil {
			log.Errorf("Wasn't able to download a thumbnail for \"%s\" from YouTube, giving up", inFileName)
			return ""
		}
	}
	img, err := imaging.Decode(reader)
	if err != nil {
		log.Errorf("Wasn't able to decode the \"%s\" thumbnail: %s", outFileName, err)
		return ""
	}
	err = imaging.Save(img, outFileName)
	if err != nil {
		log.Errorf("Wasn't able to save the \"%s\" thumbnail: %s", outFileName, err)
		return ""
	}

	return outFileName
}

func GetVideoInfo(inFileName string) *ffprobe.ProbeData {
	data, err := ffprobe.ProbeURL(context.Background(), inFileName)
	if err != nil {
		log.Errorf("Wasn't able to get video info of \"%s\": %s", inFileName, err)
		return nil
	}
	return data
}

func CalculateFramerate(data *ffprobe.ProbeData) int {
	rFrameRate := data.FirstVideoStream().RFrameRate
	split := strings.Split(rFrameRate, "/")
	upper, err := strconv.Atoi(split[0])
	if err != nil {
		return 0
	}
	lower, err := strconv.Atoi(split[1])
	if err != nil {
		return 0
	}
	return upper / lower
}
