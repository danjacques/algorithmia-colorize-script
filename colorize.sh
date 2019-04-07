set -x

API_KEY=
COLLECTION="colorize"
TIMEOUT=300

while getopts "a:h" opt; do
  case ${opt} in
    a)
      API_KEY="${OPTARG}"
      if [ -f "${API_KEY}" ]; then
	      API_KEY=$(cat "${API_KEY}")
      fi
      ;;

    c)
      COLLECTION="${OPTARG}"
      ;;

    *)
      echo "Usage: colorize.sh [-h] paths..."
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

if [ -z "${API_KEY}" ]; then
  echo "ERROR: You must supply an API key (-a)."
fi

AUTHORIZATION_HEADER="Authorization: Simple ${API_KEY}"
DATA_API="https://api.algorithmia.com/v1/data"

##
# Upload the data to Algorithmia via Data API.
##

create_collection() {
  local COLLETION=$1; shift

  curl \
    -X POST \
    -d '{"name": "'${COLLECTION}'"}' \
    -H 'Content-Type: application/json' \
    -H "${AUTHORIZATION_HEADER}" \
    "${DATA_API}/.my"
}

upload_data() {
  local COLLECTION=$1; shift
  local NAME=$1; shift
  local SOURCE=$1; shift

  if [ ! -f "${SOURCE}" ]; then
    echo "ERROR: Souce does not exist [${SOURCE}]."
    exit 1
  fi

  curl \
    -X PUT \
    -F "file=@${SOURCE}" \
    -H "${AUTHORIZATION_HEADER}" \
    "${DATA_API}/.my/${COLLECTION}"
}

##
# Download the resuting image.
##

colorize() {
  local COLLECTION=$1; shift
  local NAME=$1; shift

  local JSON_PAYLOAD='{
      "image": "data://.my/'${COLLECTION}'/'${NAME}'"
  }' 
  local ENDPOINT="https://api.algorithmia.com/v1/algo/deeplearning/ColorfulImageColorization/1.1.13?timeout=${TIMEOUT}"

  curl \
    -X POST \
    -d "${JSON_PAYLOAD}" \
    -H 'Content-Type: application/json' \
    -H "${AUTHORIZATION_HEADER}" \
    "${ENDPOINT}"
}

get_data() {
  local OUTPUT=$1; shift
  local COLLECTION=$1; shift
  local NAME=$1; shift

  local DATA_API_ALGO="data://.algo/deeplearning/ColorfulImageColorization"
  curl \
    -X GET \
    -H "${AUTHORIZATION_HEADER}" \
    -o "${OUTPUT}" \
    "${DATA_API}/.algo/deeplearning/ColorfulImageColorization/temp/${NAME}"
}

colorize_local() {
  local INPUT=$1; shift

  local INPUT_BASENAME=$(basename ${INPUT})
  local INPUT_DIRNAME=$(dirname ${INPUT})

  local OUTPUT="${INPUT%.*}.colorized.${INPUT##*.}"

  echo "Colorizing ${INPUT} => ${OUTPUT}..."
  upload_data "${COLLECTION}" "${INPUT_BASENAME}" "${INPUT}"
  colorize "${COLLECTION}" "${INPUT_BASENAME}"
  get_data "${OUTPUT}" "${COLLECTION}" "${INPUT_BASENAME}"
}

# Create our collection. This is allowed to fail if the collection already
# exists.
create_collection "${COLLECTION}"

set -e
for input; do
  colorize_local "${input}"
done
