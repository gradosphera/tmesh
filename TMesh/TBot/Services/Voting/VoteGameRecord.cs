using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TBot.Services.Voting
{
    public class VoteGameRecord
    {
        public DateTime LastVote { get; set; }

        public long DeviceId { get; set; }
    }
}
