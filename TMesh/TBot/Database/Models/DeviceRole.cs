using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TBot.Database.Models
{
    public enum DeviceRole : byte
    {
        Client = 0,
        ClientMute = 1,
        Router = 2,
        RouterClient = 3,
        Repeater = 4,
        Tracker = 5,
        Sensor = 6,
        Tak = 7,
        ClientHidden = 8,
        LostAndFound = 9,
        TakTracker = 10,
        RouterLate = 11,
        ClientBase = 12,
    }
}
