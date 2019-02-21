
#include "header.h"

#include "memorypool.c"
#include "fin.c"

#include "list.c"
#include "map.c"

#include <stdbool.h>

#ifdef COUNT_TOTAL_EXEC
int total_eval_count = 0;
#ifdef DO_CACHING
int g_cache_hits_count = 0;
#endif
#endif

#ifdef DO_CACHING
#include <string.h> /* memcpy */

int __recset_eq(void * a, void * b) {
	return a == b;
}
long unsigned int __recset_hash(void * a) {
	return (long unsigned int)a;
}
void recset_add(recursion_set * set, ff me) {
	map_add(set, me, (void*)1, __recset_hash, __recset_eq);
}
int  recset_check(recursion_set * set, ff me) {
	return 0 != map_get(set, me, __recset_hash, __recset_eq);
}
#endif

ff eval(ff me, ff x) {

#ifdef COUNT_TOTAL_EXEC
	total_eval_count++;
#endif

#ifdef DO_CACHING
	/* If we do caching, it is important to make copies of expressions,
	 * to ensure immutability */
	struct fun * my_copy = ALLOC(struct fun);
	memcpy(my_copy, me, sizeof(struct fun));
	my_copy->leafs = ALLOC_GET(me->leafs_count * sizeof(*(me->leafs)));
	if (me->customsize) {
		my_copy->custom = ALLOC_GET(me->customsize);
		memcpy(my_copy->custom, me->custom, me->customsize);
	}
	my_copy->x = x;

	mapkey_t * cache_key = list_alloc();
	recursion_set * set = map_alloc(177);
	bool efectful = my_copy->cache(my_copy, cache_key, set);

	if (efectful) {
		return my_copy->eval_now(my_copy, x);
	}

	void * find = map_get(g_caching_map, cache_key, list_to_int, list_compare_two);
	if (find) {
#ifdef COUNT_TOTAL_EXEC
		g_cache_hits_count++;
#endif
		// return my_copy->eval_now(my_copy, x);
		return find;
	} else {
		ff ret = my_copy->eval_now(my_copy, x);
		map_add(g_caching_map, cache_key, ret, list_to_int, list_compare_two);
		return ret;
	}
#else
	me->x = x;
	return me->eval_now(me, x);
#endif
}
