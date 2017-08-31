/*!
 *	B1AH Daily Email Trigger
 */

// entry point
def main = { ->
	invoke('B1AH_SANITY', '', 'master')
}

// call main
main()