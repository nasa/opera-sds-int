from hysds.es_util import get_grq_es

grq_es = get_grq_es()

print("Deleting data indices from", grq_es.es_url)

for index in grq_es.es.indices.get_alias('*').keys():
    if index[:4] == 'grq_' or index[:4] == 'hls_' or index[:4] == 'slc_' or index[:5] == 'jobs_' or index[:5] == 'cslc_' or index[:4] == 'rtc_' or index == 'batch_proc':
        print("Deleting index", index)
        print(grq_es.es.indices.delete(index=index, ignore=[404]))
