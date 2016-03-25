package trackr

import "log"

type TrackingNumber struct {
	Carrier string
	Number  string
}

%%{
	machine tracking_number;
	write data;
}%%


func findTrackingNumbers(data string) []TrackingNumber {
	// Ragel counters
	cs, p, pe, eof := 0, 0, len(data), len(data)

	// Output
	found := make([]TrackingNumber, 0, 4)

	// Matcher states
	// FedEx Express
	var fe struct {
		sum int
		start int
		end int
	}

	// FedEx Ground

	%%{
		# FedEx Express uses a checksum that multiplies digits by 3 coefficients
		# Use one action for each type of digit
		action fe1 { fe.sum += 1*(int(fc) - '0') }
		action fe3 { fe.sum += 3*(int(fc) - '0') }
		action fe7 { fe.sum += 7*(int(fc) - '0') }
		action festart { fe.start = p }
		action feend {
			log.Printf("feend");
			if ((fe.sum-7*(int(fc) - '0')) % 11) % 10 == (int(fc) - '0') {
				fe.end = p+1
			}
		}
		action feemit {
			if fe.end > fe.start {
				found = append(found, TrackingNumber{"FedEx", data[fe.start:fe.end]})
			}
		}

		# FedEx Express is either 12 or 15 digits, in the 317317317317[317] pattern
		fe = ( ( digit@fe3 digit@fe1 digit@fe7 ){4,5} @feend) >festart %feemit;

		# Tracking numbers are any of our matchers
		tracking = (fe);

		# Words could be tracking numbers (ignoring errors) or just alphanumeric strings
		word = (tracking $lerr{}) | (alnum+);

		# separators are non-alphanumeric strings
		separator = ^alnum+;

		main := separator? (word separator)* word?;

		write init;
		write exec;
	}%%

	if cs < tracking_number_first_final {
		log.Printf("%q errored!", data)
	}

	if eof == pe {
		// unused, sure
	}

	log.Printf("%q => %v", data, found)

	return found
}
